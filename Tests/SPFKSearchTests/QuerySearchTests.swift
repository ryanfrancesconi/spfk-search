// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class QuerySearchTests: TestCaseModel {
    // MARK: - Static Configs

    @Test func defaultConfigValues() {
        let config = QuerySearch.defaultConfig
        #expect(config.minScore == 0.7)
    }

    @Test func autocompleteConfigValues() {
        let config = QuerySearch.autocompleteConfig
        #expect(config.minScore == 0.6)
    }

    // MARK: - Init with minimumScore

    @Test func initWithMinimumScoreUsesTightConfig() {
        let qs = QuerySearch(
            searchableValue: ["hello"],
            query: DelimitedQuery(string: "hello"),
            minimumScore: 0.5
        )

        #expect(qs.minimumScore == 0.5)
        #expect(qs.similarity != nil)
    }

    // MARK: - Empty Inputs

    @Test func emptySearchableValueReturnsZero() {
        let qs = QuerySearch(
            searchableValue: [],
            query: DelimitedQuery(string: "test")
        )

        #expect(qs.similarity == 0)
    }

    @Test func emptyQueryReturnsZero() {
        let qs = QuerySearch(
            searchableValue: ["hello", "world"],
            query: DelimitedQuery(string: "")
        )

        #expect(qs.similarity == 0)
    }

    // MARK: - No Match

    @Test func noOverlapReturnsZero() {
        let qs = QuerySearch(
            searchableValue: ["apple", "banana"],
            query: DelimitedQuery(string: "xyz"),
            matchConfig: .init(minScore: 0.5, algorithm: .editDistance(QuerySearch.tightEditConfig))
        )

        #expect(qs.similarity == 0)
    }

    // MARK: - Score Clamping

    @Test func scoreNeverExceedsOne() {
        // First element gets 1.1x boost; verify it clamps to 1.0
        let qs = QuerySearch(
            searchableValue: ["bird", "extra"],
            query: DelimitedQuery(string: "bird"),
            matchConfig: .init(minScore: 0.1, algorithm: .editDistance(QuerySearch.tightEditConfig))
        )

        if let score = qs.similarity {
            #expect(score <= 1.0)
        }
    }

    // MARK: - minScore Boundary (>=)

    @Test func scoreAtMinScoreIsIncluded() {
        // With a minScore set to a value that should match exactly,
        // verify the score is not discarded
        let qs = QuerySearch(
            searchableValue: ["test"],
            query: DelimitedQuery(string: "test"),
            matchConfig: .init(minScore: 1.0, algorithm: .editDistance(QuerySearch.tightEditConfig))
        )

        // A perfect match for a single-element searchable should return 1.0
        // even when minScore is 1.0 (>= boundary)
        #expect(qs.similarity == 1.0)
    }
}

// MARK: - String.normalized

final class StringNormalizedTests: TestCaseModel {
    @Test func lowercasesFolding() {
        #expect("HELLO".normalized == "hello")
    }

    @Test func removesDiacritics() {
        #expect("Café".normalized == "cafe")
        #expect("naïve".normalized == "naive")
        #expect("über".normalized == "uber")
    }

    @Test func combinedCaseAndDiacritics() {
        #expect("RÉSUMÉ".normalized == "resume")
    }

    @Test func alreadyNormalized() {
        #expect("hello".normalized == "hello")
    }

    @Test func emptyString() {
        #expect("".normalized == "")
    }
}
