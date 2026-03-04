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

    // MARK: - Edge Cases

    @Test func onlyCommas() {
        let query = DelimitedQuery(string: ",,,")
        #expect(query.array.isEmpty)
    }

    @Test func singleCommaDelimitedWord() {
        // A single word with a comma present should still parse
        let query = DelimitedQuery(string: "bird,")
        #expect(query.array.contains("bird"))
        #expect(!query.array.contains(""))
    }

    @Test func shortPluralNotStripped() {
        // Words with 3 or fewer characters ending in 's' should NOT be stripped
        let query = DelimitedQuery(string: "us, bus")
        #expect(query.array.contains("us"))
        #expect(query.array.contains("bus"))
        #expect(!query.array.contains("u"))
        #expect(!query.array.contains("bu"))
    }

    @Test func longPluralIsStripped() {
        let query = DelimitedQuery(string: "bass, drums")
        #expect(query.array.contains("bass"))
        #expect(query.array.contains("bas"))
        #expect(query.array.contains("drums"))
        #expect(query.array.contains("drum"))
    }

    // MARK: - Equatable / Hashable

    @Test func equalityForSameInput() {
        let a = DelimitedQuery(string: "bird, fish")
        let b = DelimitedQuery(string: "bird, fish")
        #expect(a == b)
    }

    @Test func inequalityForDifferentInput() {
        let a = DelimitedQuery(string: "bird")
        let b = DelimitedQuery(string: "fish")
        #expect(a != b)
    }

    @Test func hashableConsistency() {
        let a = DelimitedQuery(string: "test query")
        let b = DelimitedQuery(string: "test query")
        #expect(a.hashValue == b.hashValue)
    }
}
