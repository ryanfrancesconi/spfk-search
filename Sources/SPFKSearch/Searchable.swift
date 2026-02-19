// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public typealias SearchableValue = [String]

public protocol Searchable: Sendable, Hashable {
    var searchableValue: SearchableValue { get }
}

extension Searchable {
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
