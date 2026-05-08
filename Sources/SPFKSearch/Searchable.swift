// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

/// An array of strings representing the searchable fields of a type.
///
/// The first element is given a slight scoring boost (1.1x) to prioritize
/// primary fields such as filename over secondary metadata like artist or album.
public typealias SearchableValue = [String]

/// A type whose instances can be searched by fuzzy text matching.
///
/// Conform to `Searchable` by returning an array of strings from
/// ``searchableValue``. The protocol extension provides ``similarity(to:minimumScore:)``
/// and ``similarity(to:matchConfig:)`` for free.
///
/// ```swift
/// struct AudioFile: Searchable {
///     let filename: String
///     let artist: String
///     var searchableValue: SearchableValue { [filename, artist] }
/// }
///
/// let score = audioFile.similarity(to: DelimitedQuery(string: "piano"))
/// ```
public protocol Searchable: Sendable, Hashable {
    /// The strings to match against when searching this instance.
    ///
    /// Place the most important field first — it receives a scoring boost.
    var searchableValue: SearchableValue { get }
}

extension Searchable {
    /// Returns `true` when this item has at least one searchable field that could plausibly
    /// match one of the given query terms — a fast O(n·m) gate before the full fuzzy scorer.
    ///
    /// This serves two purposes:
    ///
    /// 1. **Performance** — skips fuzzy scoring (~85% of elements for typical queries).
    ///    `FuzzyMatcher`'s internal bitmask prefilter is supposed to catch unrelated items, but
    ///    long metadata strings contain enough character variety that most items pass it regardless.
    ///
    /// 2. **Precision** — eliminates spurious fuzzy matches. Without this gate the fuzzy
    ///    scorer can return false positives (e.g. `"sci fi"` matching `"Boom, Fire, Fire Crackle"`)
    ///    because shared individual characters satisfy the scorer's edit-distance threshold.
    ///    Requiring a genuine substring connection produces more accurate results overall.
    ///
    /// The check is deliberately tolerant to avoid false negatives:
    ///
    /// - **Separator normalization** — hyphens and underscores are mapped to spaces in both
    ///   terms and candidates so `"sci-fi"` matches `"sci fi"` and vice versa.
    ///
    /// - **First-half prefix** — only the leading `max(3, count/2)` characters of each
    ///   normalized term are required to appear as a substring, which tolerates mid-word
    ///   typos and single-character insertions (e.g. `"percusion"` → checks `"perc"` →
    ///   passes `"percussion"`).
    ///
    /// - **Short-term exclusion** — terms shorter than 3 characters are excluded from the
    ///   gate entirely; when *all* terms are short the method returns `true` unconditionally
    ///   so the fuzzy scorer makes the final call.
    ///
    /// - Parameter terms: Normalised (lowercased, diacritic-folded) query terms, typically
    ///   from ``DelimitedQuery/array``.
    /// - Returns: `true` if a potential match exists or all terms are too short to gate;
    ///   `false` when no term has a near-match in any field (safe to skip fuzzy scoring).
    public func hasNearMatch(terms: [String]) -> Bool {
        let precheckTerms = terms.filter { $0.count >= 3 }
        guard precheckTerms.isNotEmpty else { return true }

        return searchableValue.contains(where: { candidate in
            // Normalize case and separators so a lowercase query term like "explo"
            // matches a title-cased candidate like "Explosion" or an uppercase one
            // like "EXPLOSIONS". Terms from DelimitedQuery are already lowercased.
            let normCandidate = candidate
                .normalized
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
            return precheckTerms.contains(where: { term in
                let normTerm = term
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                let prefix = String(normTerm.prefix(max(3, normTerm.count / 2)))
                return normCandidate.contains(prefix)
            })
        })
    }

    /// Returns the fuzzy similarity score between this instance and the query,
    /// or `nil` if no term meets the minimum score threshold.
    ///
    /// - Parameters:
    ///   - query: The parsed search query.
    ///   - minimumScore: The minimum similarity score (0–1) required to return a result.
    /// - Returns: The best match score, or `nil` if below the threshold.
    public func similarity(
        to query: DelimitedQuery,
        minimumScore: UnitInterval
    ) -> UnitInterval? {
        let querySearch = QuerySearch(
            searchableValue: searchableValue,
            query: query,
            minimumScore: minimumScore
        )

        return querySearch.similarity
    }

    /// Returns the fuzzy similarity score between this instance and the query,
    /// or `nil` if no term meets the config's minimum score.
    ///
    /// - Parameters:
    ///   - query: The parsed search query.
    ///   - matchConfig: Matching configuration. Defaults to ``QuerySearch/defaultConfig``.
    /// - Returns: The best match score, or `nil` if below the threshold.
    public func similarity(
        to query: DelimitedQuery,
        matchConfig: MatchConfig? = nil

    ) -> UnitInterval? {
        let querySearch = QuerySearch(
            searchableValue: searchableValue,
            query: query,
            matchConfig: matchConfig
        )

        return querySearch.similarity
    }
}
