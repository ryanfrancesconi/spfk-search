// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import Numerics
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class FuzzyTests: TestCaseModel {
    let customConfig = EditDistanceConfig(
        maxEditDistance: 1,
        prefixWeight: 2.0,
        substringWeight: 0.8,
        wordBoundaryBonus: 0.15,
        consecutiveBonus: 0.08,
        gapPenalty: .linear(perCharacter: 0.02)
    )

    // Disable bonuses for pure edit-distance scoring
    let noBonusConfig = EditDistanceConfig(
        wordBoundaryBonus: 0.0,
        consecutiveBonus: 0.0,
        gapPenalty: .none,
        firstMatchBonus: 0.0
    )

    // Tighter matching: increase gap penalties
    let tightConfig = EditDistanceConfig(
        substringWeight: 0.7,
        wordBoundaryBonus: 0.01,
        consecutiveBonus: 0.01,
        gapPenalty: .affine(open: 0.3, extend: 0.01),
        firstMatchBonus: 0.0
    )

    struct SearchTest: Searchable {
        let searchableValue: SearchableValue = ["bird", "fish", "frog", "bear"]
    }

    @Test func exact() async throws {
        let obj = SearchTest()

        #expect(obj.similarity(to: DelimitedQuery(string: "bird")) == 1)
        #expect(obj.similarity(to: DelimitedQuery(string: "fish")) == 0.9)
        #expect(obj.similarity(to: DelimitedQuery(string: "bear")) == 0.9)
        #expect(obj.similarity(to: DelimitedQuery(string: "frog")) == 0.9)
    }

    let froggyQuery = DelimitedQuery(string: "froggy")
    let birderQuery = DelimitedQuery(string: "birder")

    @Test func fzfConfig() async throws {
        let fzfConfig: MatchConfig = .init(
            minScore: 0.7,
            algorithm: .editDistance(.fzfAligned)
        )

        let obj = SearchTest()

        let result1 = try #require(obj.similarity(to: froggyQuery, matchConfig: fzfConfig))
        #expect(result1 > 0.7)

        let result2 = try #require(obj.similarity(to: birderQuery, matchConfig: fzfConfig))
        #expect(result2 > 0.7)
    }
}

extension FuzzyTests {
    struct SpinalTapTest: Searchable {
        let searchableValue: SearchableValue = [
            "and-oh-how-they-danced", "1984 universal records, a division of umg recordings, inc.", "soundtracks", "this is spinal tap", "this is spinal tap", "nigel tufnel", "david st. hubbins", "1/1", "viv savage", "eng", "666", "spfkmetadata", "druids", "and oh how they danced. the little children of stonehenge.beneath the haunted moon.for fear that daybreak might come too soon.", "e", "spfkmetadata", "spinal tap", "1884", "9/13", "derek smalls", "spinal tap", "spinal tap", "1984", "uk", "sony/atv music publishing llc", "stonehenge", "and oh how they danced. the little children of stonehenge. beneath the haunted moon. for fear that daybreak might come too soon", "aa6q72000047", "stonehenge! where the demons dwell. where the banshees live and they do live well. stonehenge! where a man\'s a man and the children dance to the pipes of pan.", "david st. hubbins", "1"
        ]
    }

    @Test func nearMatch() async throws {
        let obj = SpinalTapTest()

        let result = try #require(obj.similarity(to: DelimitedQuery(string: "spinal pap"), matchConfig: nil))
        #expect(result > 0.8)

        Log.debug(result)
    }

    @Test func similar() async throws {
        let obj = SpinalTapTest()

        let result = try #require(obj.similarity(to: DelimitedQuery(string: "haunted stonehenge moon"), minimumScore: 0.1))
        #expect(result == 0.9)

        Log.debug(result)
    }

    @Test func midStringMatch() async throws {
        let obj = SpinalTapTest()

        let result = try #require(obj.similarity(to: DelimitedQuery(string: "banshees"), minimumScore: 0.1))
        #expect(result > 0.5)

        Log.debug(result)
    }

    @Test func duplicate() async throws {
        let obj = SpinalTapTest()

        let result = try #require(obj.similarity(to: DelimitedQuery(string: "live"), minimumScore: 0.1))
        #expect(result > 0.5)

        Log.debug(result)
    }

    @Test func minimal() async throws {
        let obj = SpinalTapTest()

        let result = try #require(obj.similarity(to: DelimitedQuery(string: "666"), minimumScore: 0.1))
        #expect(result > 0.7)

        Log.debug(result)
    }

    @Test func firstElement() async throws {
        let querySearch = QuerySearch(
            searchableValue: ["bird_colony", "cricket_chirp, insect"],
            query: DelimitedQuery(string: "bird"),
            matchConfig: .init(
                minScore: 0.5,
                algorithm: .editDistance(tightConfig)
            )
        )

        #expect(querySearch.similarity == 1)
    }

    @Test func secondElement() async throws {
//        let pond__bird_frog = SearchableValue(array: ["pond__bird_frog", "bird"], primaryKey: "pond__bird_frog")
//        let birds_insects_river = SearchableValue(array: ["birds_insects_river", "bird"], primaryKey: "birds_insects_river")
//        let bird_colony = SearchableValue(array: ["bird_colony", "cricket_chirp, insect"], primaryKey: "bird_colony")

        let querySearch = QuerySearch(
            searchableValue: ["pen_squeal", "bird"],
            query: DelimitedQuery(string: "bird"),
            matchConfig: .init(
                minScore: 0.5,
                algorithm: .editDistance(tightConfig)
            )
        )

        #expect(querySearch.similarity == 0.9)
    }

    @Test func partialMatch() {
        let querySearch = QuerySearch(
            searchableValue: ["rewind", "music"],
            query: DelimitedQuery(string: "red"),
            matchConfig: .init(
                minScore: 0.5,
                algorithm: .editDistance(tightConfig)
            )
        )

        #expect(querySearch.similarity == 0)
    }

    @Test func partialMatch2() throws {
        let similarity = try #require(
            QuerySearch(
                searchableValue: ["rendezvous"],
                query: DelimitedQuery(string: "red"),
                matchConfig: .init(
                    minScore: 0.5,
                    algorithm: .editDistance(tightConfig)
                )
            ).similarity
        )

        #expect(similarity < 0.7)
    }

    @Test func substringMatch() throws {
        let similarity = try #require(
            QuerySearch(
                searchableValue: ["scary"],
                query: DelimitedQuery(string: "car"),
                matchConfig: .init(
                    minScore: 0.5,
                    algorithm: .editDistance(tightConfig)
                )
            ).similarity
        )

        #expect(similarity < 1)
    }
}
