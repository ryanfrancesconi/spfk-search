// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

extension QuerySearch {
    // MARK: Simple, localizedStandardRange based

    public func exactSimilarity() -> UnitInterval {
        var topScore: UnitInterval = 0

        for word in query.array {
            for value in searchableValue.array {
                var score: UnitInterval = contains(text: value, query: word)
                // var score: UnitInterval = smithWatermanSimilarity(text: value, query: word)

                guard score > 0 else {
                    continue
                }

                if score == 1 { return 1 }

                if let searchablePrimaryValue = searchableValue.primaryKey, value == searchablePrimaryValue {
                    score *= 1.2
                }

                guard score >= minimumScore else {
                    // Log.error("score: \(score) \(value): Failed to meet \(minimumScore)")
                    continue
                }

                if score > topScore {
                    topScore = score
                }
            }
        }

        return topScore.clamped(to: 0 ... 1)
    }

    private func contains(text: String, query: String) -> UnitInterval {
        guard !query.isEmpty, !text.isEmpty else { return 0.0 }

        if text == query { return 1 }

        // Perform localized search for user-friendly matching (case/diacritic insensitive)
        guard let range = text.localizedStandardRange(of: query) else {
            return 0.0
        }

        let baseScore: UnitInterval = 0.5

        let textCount = Double(text.count)
        let queryCount = Double(query.count)

        // Proximity Score (closer to 0 is better)
        // Range starts from 0 to (textCount - queryCount)
        let position = Double(
            text.distance(from: text.startIndex, to: range.lowerBound)
        )

        let maxPosition = textCount - queryCount + 1

        // Lower position = higher score
        let proximityScore = 1.0 - (position / maxPosition)

        // Length Score (longer query is better)
        let lengthScore = queryCount / textCount

        // Combined Score (Weighted combination)
        // Adjust weights, prioritize position over length
        let adjust = (0.5 * proximityScore) + (0.4 * lengthScore)

        let finalScore = baseScore + adjust

        return finalScore.clamped(to: 0 ... 1)
    }
}
