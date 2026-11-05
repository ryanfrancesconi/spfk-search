// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase
import SPFKSearch
import SPFKTesting
import Testing

@Suite(.tags(.synonyms))
struct SearchMatchTierTests {
    /// Every tier's floor sits above everything the tier below it can score, so the score alone
    /// says which way an element was reached.
    @Test func bandsNeverOverlap() {
        let tiers = SearchMatchTier.allCases.sorted(by: >)

        for (higher, lower) in zip(tiers, tiers.dropFirst()) {
            #expect(higher.band.lowerBound > lower.score(quality: 1), "\(higher) overlaps \(lower)")
        }
    }

    /// A literal score passes through unchanged, so the literal band is the scorer's own range.
    @Test func literalFloorIsTheScorersThreshold() {
        #expect(SearchMatchTier.literal.band.lowerBound == QuerySearch.defaultConfig.minScore)
    }

    @Test func literalScorePassesThrough() {
        for value: UnitInterval in [0.7, 0.83, 1] {
            #expect(SearchMatchTier.literal.score(quality: value) == value)
        }
    }

    @Test(arguments: [SearchMatchTier.curatedSynonym, .embeddedSynonym])
    func inferredScoresStayInsideTheirBand(tier: SearchMatchTier) {
        #expect(tier.score(quality: 0) == tier.band.lowerBound)
        #expect(tier.score(quality: 1) == tier.band.upperBound)

        var previous = tier.score(quality: 0)

        for step in 1 ... 20 {
            let next = tier.score(quality: UnitInterval(step) / 20)
            #expect(next >= previous)
            #expect(tier.band.contains(next))
            previous = next
        }
    }
}
