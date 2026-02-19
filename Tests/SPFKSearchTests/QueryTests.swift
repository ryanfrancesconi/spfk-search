// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import Numerics
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class QueryTests: TestCaseModel {
    @Test func space() throws {
        let query = DelimitedQuery(string: "haunted stonehenge moon")
        Log.debug(query)

        #expect(query.array == ["haunted stonehenge moon", "haunted", "stonehenge", "moon"])
    }

    @Test func comma() throws {
        let query = DelimitedQuery(string: "cow, fish")

        Log.debug(query)

        #expect(query.array == ["cow", "fish"])
    }

    @Test func malformed() throws {
        let query = DelimitedQuery(string: "   cow   , fish  ,,, , ,frog ,  , , ")

        Log.debug(query)

        #expect(query.array == ["cow", "fish", "frog"])
    }
}
