// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

public struct QuerySearch: Sendable {
    public let searchableValue: SearchableValue
    public let query: DelimitedQuery
    public let searchMethod: SearchMethod
    public let minimumScore: UnitInterval

    public private(set) var similarity: UnitInterval?

    public init(
        searchableValue: SearchableValue,
        query: DelimitedQuery,
        searchMethod: SearchMethod = .best,
        minimumScore: UnitInterval = 0.8
    ) {
        self.query = query
        self.searchableValue = searchableValue
        self.searchMethod = searchMethod
        self.minimumScore = minimumScore

        switch searchMethod {
        case .fuzzy:
            if #available(macOS 26, iOS 26, *) {
                similarity = fuzzySimilarity()
            } else {
                assertionFailure("FuzzyMatch is only available on macOS 26+")
            }

        case .exact:
            similarity = exactSimilarity()

        case .best:
            if #available(macOS 26, iOS 26, *) {
                similarity = fuzzySimilarity()
            } else {
                similarity = exactSimilarity()
            }
        }
    }
}
