// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import NaturalLanguage
import SPFKBase

/// Produces additional query terms for a search that found nothing, so `"bike"` can reach a file
/// whose only keyword is `"bicycle"`.
///
/// Two tiers run per term: ``CuratedSynonyms`` first, and if it contributes nothing, an
/// `NLEmbedding` scan constrained to the injected ``SynonymVocabulary``. Both are restricted to
/// vocabulary terms, so expansion never proposes a word no file could contain.
///
/// **This is a fallback, and callers are responsible for treating it as one** — run it only when
/// the literal search returned no results, and scale the resulting scores by
/// ``SynonymConfig/scoreCeiling`` after applying the minimum-score filter. Running it
/// unconditionally would let an inferred match outrank a literal one.
///
/// ```swift
/// let expander = SynonymExpander(vocabulary: visionVocabulary)
/// let extra = expander.expansions(for: query.array)   // ["bicycle"]
/// ```
public struct SynonymExpander: Sendable {
    /// The terms expansion is allowed to propose.
    public let vocabulary: SynonymVocabulary

    /// Tuning; see ``SynonymConfig``.
    public let config: SynonymConfig

    /// Terms shorter than this are not sent to the *embedding* tier — they carry too little
    /// signal and land near far too much of any vocabulary.
    ///
    /// The curated tier has no such limit: a short entry there is deliberate, and `"tv"` →
    /// `"television"` is exactly the kind of query this feature exists to serve.
    static let minimumEmbeddedTermLength = 3

    /// Vocabulary match forms keyed by their lowercased spelling, for the curated tier's
    /// membership check.
    private let matchFormsByLowercase: [String: String]

    public init(vocabulary: SynonymVocabulary, config: SynonymConfig = .default) {
        self.vocabulary = vocabulary
        self.config = config

        matchFormsByLowercase = Dictionary(
            vocabulary.terms.map { ($0.matchForm.lowercased(), $0.matchForm) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Additional terms to search for, excluding anything already in `terms`.
    ///
    /// - Parameter terms: The original query terms, normalized (lowercased, diacritic-folded) —
    ///   typically `DelimitedQuery.array`.
    /// - Returns: Expansion terms in vocabulary match form, deduplicated, or an empty array when
    ///   nothing qualifies.
    public func expansions(for terms: [String]) -> [String] {
        guard vocabulary.terms.isNotEmpty else { return [] }

        let original = Set(terms.map { $0.lowercased() })
        let embedding = config.usesEmbedding ? NLEmbedding.wordEmbedding(for: .english) : nil

        var seen = Set<String>()
        var result: [String] = []

        for term in terms {
            for expansion in expansions(for: term, embedding: embedding) {
                let key = expansion.lowercased()

                // Never re-propose something the user already typed, and never repeat an
                // expansion another term already contributed.
                guard !original.contains(key), seen.insert(key).inserted else { continue }

                result.append(expansion)
            }
        }

        return result
    }

    // MARK: - Private

    private func expansions(for term: String, embedding: NLEmbedding?) -> [String] {
        // The lemma is a lookup key only -- it never replaces the user's term. "biking" still
        // matches "biking"; it just additionally reaches "bicycle" via "bike".
        let lemma = Lemmatizer.lemma(for: term)

        if config.usesCuratedTable {
            let curated = curatedExpansions(for: term, lemma: lemma)

            // A curated hit is authoritative -- skip the embedding tier for this term rather
            // than diluting a known-good answer with its neighbors.
            if curated.isNotEmpty { return curated }
        }

        guard let embedding, term.count >= Self.minimumEmbeddedTermLength else { return [] }

        return embeddedExpansions(for: term, lemma: lemma, embedding: embedding)
    }

    /// Curated synonyms of `term` (or its lemma) that the vocabulary actually contains.
    private func curatedExpansions(for term: String, lemma: String?) -> [String] {
        var candidates = CuratedSynonyms.synonyms(for: term)

        if let lemma {
            candidates += CuratedSynonyms.synonyms(for: lemma)
        }

        return candidates.compactMap { matchFormsByLowercase[$0.lowercased()] }
    }

    /// Vocabulary terms within ``SynonymConfig/maximumDistance`` of `term`, closest first.
    private func embeddedExpansions(
        for term: String,
        lemma: String?,
        embedding: NLEmbedding
    ) -> [String] {
        let queries = queryVectors(for: term, lemma: lemma, embedding: embedding)
        guard queries.isNotEmpty else { return [] }

        var scored: [(term: String, distance: Double)] = []

        for candidate in vocabulary.terms {
            guard let vector = candidate.vector else { continue }

            // Best distance across the term and its lemma -- whichever spelling gets closest
            // is the one that decides, since they are two spellings of one search intent.
            var best: Double?

            for query in queries {
                guard let distance = SynonymVocabulary.cosineDistance(
                    query.vector, normA: query.norm,
                    vector, normB: candidate.norm
                ) else { continue }

                if best == nil || distance < (best ?? 0) { best = distance }
            }

            guard let best, best <= config.maximumDistance else { continue }

            scored.append((candidate.matchForm, best))
        }

        return scored
            .sorted { $0.distance < $1.distance }
            .prefix(config.maximumExpansionsPerTerm)
            .map(\.term)
    }

    /// Embedding vectors to search with: the term's own, plus its lemma's when they differ.
    ///
    /// **Both are used, not one as a fallback for the other.** An inflected form usually *has* a
    /// vector — `"biking"` does — it is just the wrong one, clustering with `hiking`/`rafting`
    /// rather than reaching `bicycle`. Treating the lemma as a fallback for a missing vector
    /// would therefore never fire on the very case lemmatization exists to fix. Searching both
    /// also avoids the opposite hazard, where a lemma changes meaning outright (`glasses` →
    /// `glass`) and would lose the original sense if it replaced the term.
    ///
    /// Multi-word terms are averaged the same way vocabulary entries are — `DelimitedQuery` keeps
    /// the whole phrase as a term for space-delimited input, and `NLEmbedding` has no vector for
    /// a phrase.
    private func queryVectors(
        for term: String,
        lemma: String?,
        embedding: NLEmbedding
    ) -> [(vector: [Double], norm: Double)] {
        var spellings = [term]

        if let lemma { spellings.append(lemma) }

        return spellings.compactMap { spelling in
            guard let vector = SynonymVocabulary.meanVector(of: spelling.snakeCaseWords, in: embedding)
            else { return nil }

            let norm = SynonymVocabulary.magnitude(vector)
            guard norm > 0 else { return nil }

            return (vector, norm)
        }
    }
}
