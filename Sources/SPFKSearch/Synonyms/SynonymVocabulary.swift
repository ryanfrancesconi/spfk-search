// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import NaturalLanguage
import SoundAnalysis
import SPFKBase
import Vision

/// The closed set of terms synonym expansion is allowed to propose.
///
/// Expansion is constrained to a vocabulary rather than taking `NLEmbedding`'s free nearest
/// neighbors, which return the top matches across the entire embedding and can only ever suggest
/// words no file contains. ``master`` holds the classifier labels both products write as keywords;
/// a product composes its own subject matter onto it with ``adding(identifiers:)``.
///
/// ```swift
/// let vocabulary = SynonymVocabulary.master.adding(identifiers: ["riser", "whoosh"])
/// ```
public struct SynonymVocabulary: Sendable {
    /// One vocabulary entry, in both of the forms expansion needs.
    public struct Term: Sendable {
        /// Space-separated form, corresponding to how the term is stored in file metadata.
        /// This is what gets emitted as an expansion and matched against searchable text.
        public let matchForm: String

        /// Component words, each embedded separately.
        ///
        /// Compounds need this because **`NLEmbedding` has no vector for a multi-word string** -
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

    private init(terms: [Term]) {
        self.terms = terms
    }

    /// Builds a vocabulary from raw classification identifiers, each match form embedded once.
    ///
    /// Identifiers are decomposed with ``Swift/String/snakeCaseWords`` - the same parse that
    /// produces the stored keyword form - so the match form and the embedding decomposition
    /// cannot drift apart. Matching folds case on both sides, so only word separation matters.
    ///
    /// - Parameter identifiers: Raw identifiers, e.g. `["toaster_oven", "bicycle"]`.
    public init(identifiers: [String]) {
        self.init(terms: Self.embed(identifiers, excluding: []))
    }

    /// The union with `other`, keeping this vocabulary's term where both hold the same match form.
    /// Each side's vectors are reused, so nothing is embedded again.
    public func adding(_ other: SynonymVocabulary) -> SynonymVocabulary {
        var seen = Set<String>()
        var merged: [Term] = []
        merged.reserveCapacity(terms.count + other.terms.count)

        for term in terms + other.terms where seen.insert(term.matchForm.lowercased()).inserted {
            merged.append(term)
        }

        return SynonymVocabulary(terms: merged)
    }

    /// ``adding(_:)`` for raw identifiers, embedding only the match forms this vocabulary lacks.
    public func adding(identifiers: [String]) -> SynonymVocabulary {
        let held = Set(terms.map { $0.matchForm.lowercased() })
        return SynonymVocabulary(terms: terms + Self.embed(identifiers, excluding: held))
    }

    private static func embed(_ identifiers: [String], excluding held: Set<String>) -> [Term] {
        let embedding = NLEmbedding.wordEmbedding(for: .english)
        var seen = held

        return identifiers.compactMap { identifier in
            let words = identifier.snakeCaseWords
            guard words.isNotEmpty else { return nil }

            let matchForm = words.joined(separator: " ")
            guard seen.insert(matchForm.lowercased()).inserted else { return nil }

            let vector = embedding.flatMap { meanVector(of: words, in: $0) }

            return Term(matchForm: matchForm, words: words, vector: vector, norm: vector.map(magnitude) ?? 0)
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

// MARK: - Master

extension SynonymVocabulary {
    /// Vision's image labels and SoundAnalysis's sound labels: the words Detect Keywords writes
    /// in both products. Built on first use; build it off the main thread before a synchronous
    /// caller reads it.
    ///
    /// A classifier that cannot report its labels is logged and left out, so this may be empty.
    public static let master: SynonymVocabulary = {
        var identifiers: [String] = []

        do {
            identifiers += try VNClassifyImageRequest().supportedIdentifiers()
        } catch {
            Log.error("Couldn't read Vision's classification labels for related-word search:", error)
        }

        do {
            identifiers += try SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications
        } catch {
            Log.error("Couldn't read SoundAnalysis's classification labels for related-word search:", error)
        }

        return SynonymVocabulary(identifiers: identifiers)
    }()
}
