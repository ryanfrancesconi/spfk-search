// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

extension QuerySearch {
    @available(macOS 26, iOS 26, *)
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
                }

                guard score > matchConfig.minScore else { continue }

                Log.debug("'\(word)' matching '\(value)' = \(wordScore), \(matchConfig.minScore)")

                if score > topScore {
                    topScore = score
                }
            }
        }

        return topScore.clamped(to: 0 ... 1)
    }
}

extension QuerySearch {
    /// Experiment
    /// Returns a similarity score from 0.0 to 1.0 using local alignment.
    func smithWatermanSimilarity(text: String, query: String) -> UnitInterval {
        guard !query.isEmpty, !text.isEmpty else { return 0.0 }

        let matchWeight = 2
        let mismatchPenalty = 1
        let gapPenalty = 1

        let sChars = Array(text)
        let qChars = Array(query)

        var matrix = Array(
            repeating: Array(repeating: 0, count: sChars.count + 1),
            count: qChars.count + 1
        )

        var maxScore = 0

        for i in 1 ... qChars.count {
            for j in 1 ... sChars.count {
                let cost = qChars[i - 1] == sChars[j - 1] ? matchWeight : -mismatchPenalty

                matrix[i][j] = max(
                    0,
                    matrix[i - 1][j - 1] + cost, // Diagonal
                    matrix[i - 1][j] - gapPenalty, // Up (Gap in 'self')
                    matrix[i][j - 1] - gapPenalty // Left (Gap in 'query')
                )

                if matrix[i][j] > maxScore {
                    maxScore = matrix[i][j]
                }
            }
        }

        // Perfect score is the query length times the match weight
        let perfectScore = qChars.count * matchWeight

        return Double(maxScore) / Double(perfectScore)
    }
}
