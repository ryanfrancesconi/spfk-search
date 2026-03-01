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

    @Test func empty() throws {
        let query = DelimitedQuery(string: "")

        #expect(query.array == [])
        #expect(query.originalString == "")
    }

    @Test func singleWord() throws {
        let query = DelimitedQuery(string: "bird")

        #expect(query.array == ["bird"])
        #expect(query.originalString == "bird")
    }

    @Test func pluralStripping() throws {
        let query = DelimitedQuery(string: "birds, cats")

        // "birds" and "cats" should each produce a singular variant
        #expect(query.array.contains("birds"))
        #expect(query.array.contains("cats"))
        #expect(query.array.contains("bird"))
        #expect(query.array.contains("cat"))
    }

    @Test func pluralStrippingSpaceDelimited() throws {
        let query = DelimitedQuery(string: "dogs frogs")

        // Full string is kept, plus individual words, plus singulars
        #expect(query.array.contains("dogs frogs"))
        #expect(query.array.contains("dogs"))
        #expect(query.array.contains("frogs"))
        #expect(query.array.contains("dog"))
        #expect(query.array.contains("frog"))
    }

    @Test func normalization() throws {
        let query = DelimitedQuery(string: "Café")

        // Normalized form should be lowercased and diacritic-insensitive
        #expect(query.array.first == "cafe")
        #expect(query.originalString == "Café")
    }
}
