// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

/// Computes a fuzzy similarity score between a ``DelimitedQuery`` and a ``SearchableValue``.
///
/// `QuerySearch` pairs every query term against every searchable string,
/// delegates scoring to `FuzzyMatcher`, applies positional weighting
/// (first element gets a 1.1x boost), and returns the best score that meets
/// the minimum threshold.
///
/// Use one of the preset configurations — ``defaultConfig`` for general search
/// or ``autocompleteConfig`` for type-ahead — or provide a custom `MatchConfig`.
///
/// ```swift
/// let search = QuerySearch(
///     searchableValue: ["stonehenge", "spinal tap"],
///     query: DelimitedQuery(string: "stone"),
///     matchConfig: QuerySearch.autocompleteConfig
/// )
/// search.similarity  // e.g. 0.85
/// ```
public struct QuerySearch: Sendable {
    /// The strings being searched against.
    public let searchableValue: SearchableValue

    /// The parsed query to match.
    public let query: DelimitedQuery

    /// The matching configuration controlling algorithm, thresholds, and weights.
    public let matchConfig: MatchConfig

    /// The computed similarity score (0–1), or `nil` if no term met the minimum threshold.
    public private(set) var similarity: UnitInterval?

    /// The minimum score required from ``matchConfig``.
    public var minimumScore: UnitInterval {
        matchConfig.minScore
    }

    /// Strict edit-distance configuration with elevated gap penalties and minimal bonuses.
    public static let tightEditConfig = EditDistanceConfig(
        substringWeight: 0.7,
        wordBoundaryBonus: 0.01,
        consecutiveBonus: 0.01,
        gapPenalty: .affine(open: 0.3, extend: 0.01),
        firstMatchBonus: 0.0
    )

    /// General-purpose matching configuration (minScore 0.7, tight edit distance).
    public static let defaultConfig: MatchConfig = .init(
        minScore: 0.7,
        algorithm: .editDistance(tightEditConfig)
    )

    /// Type-ahead configuration with prefix weighting and a lower minimum score (0.6).
    public static let autocompleteConfig = MatchConfig(
        minScore: 0.6,
        algorithm: .editDistance(EditDistanceConfig(
            maxEditDistance: 1,
            prefixWeight: 2.0,
            substringWeight: 0.8
        ))
    )

    /// Creates a search with an explicit minimum score threshold using ``tightEditConfig``.
    ///
    /// - Parameters:
    ///   - searchableValue: The strings to match against.
    ///   - query: The parsed search query.
    ///   - minimumScore: Minimum similarity score (0–1) for a result to be considered.
    public init(
        searchableValue: SearchableValue,
        query: DelimitedQuery,
        minimumScore: UnitInterval
    ) {
        let config: MatchConfig = .init(
            minScore: minimumScore,
            algorithm: .editDistance(Self.tightEditConfig)
        )

        self = QuerySearch(searchableValue: searchableValue, query: query, matchConfig: config)
    }

    /// Creates a search with an optional match configuration.
    ///
    /// The similarity score is computed immediately during initialization.
    ///
    /// - Parameters:
    ///   - searchableValue: The strings to match against.
    ///   - query: The parsed search query.
    ///   - matchConfig: Matching configuration. Defaults to ``defaultConfig``.
    public init(
        searchableValue: SearchableValue,
        query: DelimitedQuery,
        matchConfig: MatchConfig? = nil
    ) {
        self.query = query
        self.searchableValue = searchableValue

        self.matchConfig = matchConfig ?? Self.defaultConfig

        similarity = fuzzySimilarity()
    }
}
