// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public protocol Searchable: Sendable, Hashable {
    var searchableValue: SearchableValue { get }
}

extension Searchable {
    public func similarity(
        to query: DelimitedQuery,
        searchMethod: SearchMethod = .best,
        minimumScore: UnitInterval = 0.7
    ) -> UnitInterval? {
        let querySearch = QuerySearch(
            searchableValue: searchableValue,
            query: query,
            searchMethod: searchMethod,
            minimumScore: minimumScore
        )

        return querySearch.similarity
    }
}

public struct SearchableValue: Sendable, Hashable {
    public let array: [String]
    public let primaryKey: String?

    public init(array: [String], primaryKey: String?) {
        self.array = array
        self.primaryKey = primaryKey
    }
}
