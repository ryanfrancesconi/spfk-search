// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

extension QuerySearch {
    public func fuzzySimilarity() -> UnitInterval {
        var topScore: UnitInterval = 0

        let matcher = FuzzyMatcher(config: matchConfig)
        var buffer = matcher.makeBuffer()

        let queryCount = query.array.count
        let searchableCount = searchableValue.count

        for i in 0 ..< queryCount {
            let word = query.array[i]

            let fuzzyQuery = matcher.prepare(word)

            for j in 0 ..< searchableCount {
                let value = searchableValue[j]

                guard let wordScore = matcher.score(value, against: fuzzyQuery, buffer: &buffer) else { continue }

                var score = wordScore.score

                // give extra weight if is the first element, generally filename
                if searchableCount > 1 {
                    score *= (j == 0 ? 1.1 : 0.9)
                    score = min(score, 1.0)
                }

                guard score >= matchConfig.minScore else { continue }

                #if DEBUG
                Log.debug("'\(word)' matching '\(value)' = \(wordScore), \(matchConfig.minScore)")
                #endif

                if score > topScore {
                    topScore = score
                    if topScore >= 1.0 { return 1.0 }
                }
            }
        }

        return topScore.clamped(to: 0 ... 1)
    }
}
