// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import Numerics
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class SearchableTests: TestCaseModel {
    @available(macOS 26, iOS 26, *)
    @Test func search() async throws {
        struct Object: Searchable {
            let searchableValue: SearchableValue = .init(array: ["bird", "fish", "frog", "bear"], primaryKey: "bird")
        }

        let obj = Object()

        #expect(obj.similarity(to: DelimitedQuery(string: "bird"), searchMethod: .exact) == 1)
        #expect(obj.similarity(to: DelimitedQuery(string: "fish"), searchMethod: .exact) == 1)
        #expect(obj.similarity(to: DelimitedQuery(string: "bear"), searchMethod: .exact) == 1)
        #expect(obj.similarity(to: DelimitedQuery(string: "frog"), searchMethod: .exact) == 1)

        #expect(obj.similarity(to: DelimitedQuery(string: "bird"), searchMethod: .fuzzy) == 1)
        #expect(obj.similarity(to: DelimitedQuery(string: "frog"), searchMethod: .fuzzy) == 0.8)

        let froggy = try #require(
            obj.similarity(
                to: DelimitedQuery(string: "froggy"),
                searchMethod: .fuzzy,
                minimumScore: 0.6
            )
        )
        #expect(froggy.isApproximatelyEqual(to: 0.6, absoluteTolerance: 0.1))

        let birder = try #require(
            obj.similarity(
                to: DelimitedQuery(string: "birder"),
                searchMethod: .fuzzy,
                minimumScore: 0.6
            )
        )
        #expect(birder.isApproximatelyEqual(to: 0.7, absoluteTolerance: 0.1))
    }
}
