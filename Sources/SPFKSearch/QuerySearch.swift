// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public struct QuerySearch: Sendable {
    public let searchableValue: SearchableValue
    public let query: DelimitedQuery
    public let matchConfig: MatchConfig

    public private(set) var similarity: UnitInterval?

    public var minimumScore: UnitInterval {
        matchConfig.minScore
    }

    /**
     maxEditDistance: Int = 2,
     longQueryMaxEditDistance: Int = 3,
     longQueryThreshold: Int = 13,
     prefixWeight: Double = 1.5,
     substringWeight: Double = 1.0,
     wordBoundaryBonus: Double = 0.1,
     consecutiveBonus: Double = 0.05,
     gapPenalty: GapPenalty = .default,
     firstMatchBonus: Double = 0.15,
     firstMatchBonusRange: Int = 10,
     lengthPenalty: Double = 0.003,
     acronymWeight: Double = 1.0
     */

    /// Tighter matching: increase gap penalties
    public static let tightEditConfig = EditDistanceConfig(
        substringWeight: 0.7,
        wordBoundaryBonus: 0.01,
        consecutiveBonus: 0.01,
        gapPenalty: .affine(open: 0.3, extend: 0.01),
        firstMatchBonus: 0.0
    )

    public static let defaultConfig: MatchConfig = .init(
        minScore: 0.7,
        algorithm: .editDistance(tightEditConfig)
    )

    public static let autocompleteConfig = MatchConfig(
        minScore: 0.6,
        algorithm: .editDistance(EditDistanceConfig(
            maxEditDistance: 1,
            prefixWeight: 2.0,
            substringWeight: 0.8
        ))
    )

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

    public init(
        searchableValue: SearchableValue,
        query: DelimitedQuery,
        matchConfig: MatchConfig? = nil
    ) {
        self.query = query
        self.searchableValue = searchableValue

        self.matchConfig = matchConfig ?? Self.defaultConfig

        if #available(macOS 26, iOS 26, *) {
            similarity = fuzzySimilarity()
        } else {
            similarity = exactSimilarity()
        }
    }
}
