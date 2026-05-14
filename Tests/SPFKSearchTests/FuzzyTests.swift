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

    @Test func autocompleteConfig() throws {
        let querySearch = QuerySearch(
            searchableValue: ["stonehenge"],
            query: DelimitedQuery(string: "stone"),
            matchConfig: QuerySearch.autocompleteConfig
        )

        let similarity = try #require(querySearch.similarity)
        #expect(similarity > 0.6)
    }

    @Test func autocompleteNoMatch() {
        let querySearch = QuerySearch(
            searchableValue: ["bird"],
            query: DelimitedQuery(string: "xyz"),
            matchConfig: QuerySearch.autocompleteConfig
        )

        #expect(querySearch.similarity == 0)
    }

    /// Calibrates the fuzzy minScore threshold by scoring known-good and known-bad word pairs
    /// across the range [0.50, 0.90] and finding where bad pairs are blocked.
    ///
    /// Run this test to justify (or adjust) the minScore constant in UCSDetector.
    /// A "good" pair is a legitimate match (misspelling, plural, truncation).
    /// A "bad" pair is a character-level coincidence that should NOT match.
    ///
    /// Note: gerund→base forms (e.g. "roaring"→"Roar") score below 0.64 due to Jaro-Winkler
    /// length-difference penalties. This is acceptable — the UCS database provides multiple
    /// synonym forms per entry, so a gerund will match via another term.
    @Test func minScoreCalibration() throws {
        struct Pair {
            let query: String
            let candidate: String
        }

        // Pairs that SHOULD match — same-root word, different form (plural, typo, gerund).
        let goodPairs: [Pair] = [
            Pair(query: "growls",    candidate: "Growl"),         // -s suffix
            Pair(query: "lions",     candidate: "Lion"),           // -s suffix
            Pair(query: "explosoin", candidate: "Explosion"),      // 1-char transposition typo
            Pair(query: "footsteps", candidate: "Footstep"),       // plural→singular
            Pair(query: "howls",     candidate: "Howl"),           // -s suffix
            Pair(query: "snarls",    candidate: "Snarl"),          // -s suffix
            // Gerund→gerund: the database now includes *ing forms, so these are valid pairs.
            Pair(query: "growling",  candidate: "Growling"),       // exact gerund
            Pair(query: "roaring",   candidate: "Roaring"),        // exact gerund
            Pair(query: "howling",   candidate: "Howling"),        // exact gerund
            Pair(query: "snarling",  candidate: "Snarling"),       // exact gerund
            Pair(query: "hissing",   candidate: "Hissing"),        // exact gerund
        ]

        // Pairs that should NOT match — real English words sharing characters by coincidence.
        let badPairs: [Pair] = [
            Pair(query: "lion",    candidate: "Ignite"),          // Jaro char coincidence (~0.55)
            Pair(query: "growls",  candidate: "Gallop"),          // share g, o, l (~0.60-0.63)
            Pair(query: "roar",    candidate: "Burn"),            // short overlap
            Pair(query: "hiss",    candidate: "Wind"),            // unrelated
            Pair(query: "lion",    candidate: "Friction"),        // no meaningful overlap
            Pair(query: "thunder", candidate: "Grind"),           // unrelated
        ]

        let algorithm = QuerySearch.defaultConfig.algorithm

        // Show raw scores for all pairs before the threshold sweep.
        let diagConfig = MatchConfig(minScore: 0.0, algorithm: algorithm)
        let diagMatcher = FuzzyMatcher(config: diagConfig)
        var diagBuffer = diagMatcher.makeBuffer()

        Log.debug("--- Raw pair scores (no minScore gate) ---")
        Log.debug("GOOD pairs:")
        for pair in goodPairs {
            let q = diagMatcher.prepare(pair.query)
            let score = diagMatcher.score(pair.candidate, against: q, buffer: &diagBuffer)?.score ?? 0
            let lhs = pair.query.padding(toLength: 14, withPad: " ", startingAt: 0)
            let rhs = pair.candidate.padding(toLength: 14, withPad: " ", startingAt: 0)
            Log.debug(String(format: "  %@ → %@  %.4f", lhs, rhs, score))
        }
        Log.debug("BAD pairs:")
        for pair in badPairs {
            let q = diagMatcher.prepare(pair.query)
            let score = diagMatcher.score(pair.candidate, against: q, buffer: &diagBuffer)?.score ?? 0
            let lhs = pair.query.padding(toLength: 14, withPad: " ", startingAt: 0)
            let rhs = pair.candidate.padding(toLength: 14, withPad: " ", startingAt: 0)
            Log.debug(String(format: "  %@ → %@  %.4f", lhs, rhs, score))
        }

        // Threshold sweep.
        let stride = 0.01
        var results: [(threshold: Double, goodPass: Int, badPass: Int)] = []
        var t = 0.50
        while t <= 0.90 + 1e-9 {
            let threshold = (t * 100).rounded() / 100
            let config = MatchConfig(minScore: threshold, algorithm: algorithm)
            let matcher = FuzzyMatcher(config: config)
            var buffer = matcher.makeBuffer()

            var goodPass = 0
            for pair in goodPairs {
                let q = matcher.prepare(pair.query)
                if let s = matcher.score(pair.candidate, against: q, buffer: &buffer), s.score >= threshold {
                    goodPass += 1
                }
            }

            var badPass = 0
            for pair in badPairs {
                let q = matcher.prepare(pair.query)
                if let s = matcher.score(pair.candidate, against: q, buffer: &buffer), s.score >= threshold {
                    badPass += 1
                }
            }

            results.append((threshold, goodPass, badPass))
            t += stride
        }

        Log.debug("\nthreshold | good (\(goodPairs.count)) | bad (\(badPairs.count))")
        Log.debug(String(repeating: "-", count: 34))
        for r in results {
            Log.debug(String(format: "  %.2f    |   %d        |  %d", r.threshold, r.goodPass, r.badPass))
        }

        // Find first threshold where all bad pairs are blocked (primary goal).
        let allBadBlocked = results.first(where: { $0.badPass == 0 })

        // Find the ideal: all good pass AND no bad pass.
        let perfectCrossover = results.last(where: { $0.goodPass == goodPairs.count && $0.badPass == 0 })

        if let c = perfectCrossover {
            Log.debug(String(format: "\nPerfect crossover at %.2f: all %d good pass, 0 bad pass.", c.threshold, goodPairs.count))
        } else if let b = allBadBlocked {
            Log.debug(String(format: "\nAll bad pairs blocked from %.2f onward (%d/%d good still pass).", b.threshold, b.goodPass, goodPairs.count))
            Log.debug("Gerund→base pairs score below threshold by design — the database covers them via alternate synonym entries.")
        }

        // Must have some threshold where all noise matches are blocked.
        let blockThreshold = allBadBlocked?.threshold
        #expect(blockThreshold != nil, "No threshold in [0.50, 0.90] blocks all bad pairs — the fuzzy algorithm may be too lenient for UCS use")

        if let bt = blockThreshold {
            // All good pairs must still pass at the block threshold.
            // (Some gerund→base forms score below this — they're intentionally excluded from goodPairs.)
            let row = results.first(where: { $0.threshold == bt })!
            #expect(row.goodPass == goodPairs.count,
                "At the bad-blocking threshold (%.2f), only \(row.goodPass)/\(goodPairs.count) good pairs pass — add more synonym coverage or lower minScore")
        }
    }
}
