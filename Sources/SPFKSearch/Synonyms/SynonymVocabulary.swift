// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import NaturalLanguage
import SPFKBase

/// The closed set of terms synonym expansion is allowed to propose.
///
/// Expansion is constrained to a vocabulary rather than taking `NLEmbedding`'s free nearest
/// neighbors, which return the top matches across the entire embedding and can only ever suggest
/// words no file contains.
///
/// The vocabulary is supplied by the caller — `spfk-search` ships no taxonomy of its own. TorchTag
/// injects Vision's classification identifiers; ShadowTag's UCS terms are the same shape. This is
/// not merely a preference: `spfk-processing` (which owns UCS) already depends on `spfk-search`,
/// so owning that vocabulary here would be a dependency cycle.
///
/// ```swift
/// let vocabulary = SynonymVocabulary(identifiers: try VNClassifyImageRequest().supportedIdentifiers())
/// ```
public struct SynonymVocabulary: Sendable {
    /// One vocabulary entry, in both of the forms expansion needs.
    public struct Term: Sendable {
        /// Space-separated form, corresponding to how the term is stored in file metadata.
        /// This is what gets emitted as an expansion and matched against searchable text.
        public let matchForm: String

        /// Component words, each embedded separately.
        ///
        /// Compounds need this because **`NLEmbedding` has no vector for a multi-word string** —
        /// `vector(for: "mountain bike")` is nil, not a poor match. 193 of Vision's 1303
        /// identifiers are compound, so treating them as single tokens would silently drop ~15%
        /// of the vocabulary out of embedding expansion with no error.
        public let words: [String]

        /// Mean of the component word vectors, or `nil` when no component is in the embedding's
        /// vocabulary (serial numbers, invented words, proper nouns).
        let vector: [Double]?

        /// Cached magnitude of ``vector``, so the per-query scan does not recompute it.
        let norm: Double
    }

    public let terms: [Term]

    /// Builds a vocabulary from raw classification identifiers.
    ///
    /// Identifiers are decomposed with ``Swift/String/snakeCaseWords`` — the same parse that
    /// produces the stored keyword form — so the match form and the embedding decomposition
    /// cannot drift apart.
    ///
    /// Casing is not normalized here and does not need to be: matching folds case on both sides
    /// (`DelimitedQuery` folds the query, searchable values are folded when built), so only word
    /// separation matters.
    ///
    /// - Parameter identifiers: Raw identifiers, e.g. `["toaster_oven", "bicycle"]`.
    public init(identifiers: [String]) {
        let embedding = NLEmbedding.wordEmbedding(for: .english)

        terms = identifiers.compactMap { identifier in
            let words = identifier.snakeCaseWords
            guard words.isNotEmpty else { return nil }

            let vector = embedding.flatMap { Self.meanVector(of: words, in: $0) }

            return Term(
                matchForm: words.joined(separator: " "),
                words: words,
                vector: vector,
                norm: vector.map(Self.magnitude) ?? 0
            )
        }
    }

    // MARK: - Internal

    /// Mean of the embedding vectors for `words`, ignoring words the embedding does not know.
    /// Returns `nil` when none of them are known.
    static func meanVector(of words: [String], in embedding: NLEmbedding) -> [Double]? {
        var sum: [Double] = []
        var count = 0

        for word in words {
            guard let vector = embedding.vector(for: word.lowercased()) else { continue }

            if sum.isEmpty {
                sum = vector
            } else {
                for i in sum.indices { sum[i] += vector[i] }
            }
            count += 1
        }

        guard count > 0 else { return nil }

        if count > 1 {
            for i in sum.indices { sum[i] /= Double(count) }
        }
        return sum
    }

    static func magnitude(_ vector: [Double]) -> Double {
        var sum = 0.0
        for value in vector { sum += value * value }
        return sum.squareRoot()
    }

    /// Cosine distance in `0...2`, or `nil` if either side has no magnitude.
    static func cosineDistance(
        _ a: [Double], normA: Double,
        _ b: [Double], normB: Double
    ) -> Double? {
        guard normA > 0, normB > 0, a.count == b.count else { return nil }

        var dot = 0.0
        for i in a.indices { dot += a[i] * b[i] }

        return 1 - dot / (normA * normB)
    }
}
