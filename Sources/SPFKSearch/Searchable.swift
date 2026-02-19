// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public protocol Searchable: Sendable, Hashable {
    var searchableArray: [String] { get }
    var searchablePrimaryValue: String? { get }
}

extension Searchable {
    public var searchablePrimaryValue: String? { nil }
}

extension Searchable {
    public func similarity(
        to query: DelimitedQuery,
        searchMethod: SearchMethod = .best,
        minimumScore: UnitInterval = 0.7
    ) -> UnitInterval? {
        QuerySearch(
            source: self,
            query: query,
            searchMethod: searchMethod,
            minimumScore: minimumScore
        ).similarity
    }
}
