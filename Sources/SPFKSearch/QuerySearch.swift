// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public struct QuerySearch: Sendable {
    public let source: any Searchable
    public let query: DelimitedQuery
    public let searchMethod: SearchMethod
    public let minimumScore: UnitInterval

    public private(set) var similarity: UnitInterval?

    public init(
        source: any Searchable,
        query: DelimitedQuery,
        searchMethod: SearchMethod = .best,
        minimumScore: UnitInterval = 0.8
    ) {
        self.query = query
        self.source = source
        self.searchMethod = searchMethod
        self.minimumScore = minimumScore

        switch searchMethod {
        case .fuzzy:
            if #available(macOS 26, iOS 26, *) {
                similarity = fuzzySimilarity()
            } else {
                assertionFailure("Fuzzy search is only available on macOS 26+")
            }

        case .exact:
            similarity = exactSimilarity()

        case .best:
            if #available(macOS 26, iOS 26, *) {
                similarity = fuzzySimilarity()
            } else {
                similarity = exactSimilarity()
            }
        }
    }
}

extension QuerySearch {
    @available(macOS 26, iOS 26, *)
    public func fuzzySimilarity() -> UnitInterval {
        var topScore: UnitInterval = 0

        let matcher = FuzzyMatcher()
        var buffer = matcher.makeBuffer()

        for word in query.array {
            let query = matcher.prepare(word)

            for value in source.searchableArray {
                guard let wordScore = matcher.score(value, against: query, buffer: &buffer) else { continue }

                var score = wordScore.score * 0.8

                // Log.debug("\(value) = \(wordScore)")

                // give extra weight if there is a primary search value assigned,
                // such a match to the filename
                if let searchablePrimaryValue = source.searchablePrimaryValue,
                   value == searchablePrimaryValue
                {
                    score *= 1.2
                }

                guard score >= minimumScore else { continue }

                if score == 1 { return 1 }

                if score > topScore {
                    topScore = score
                }
            }
        }

        return topScore
    }
}

extension QuerySearch {
    // MARK: Simple, localizedStandardRange based

    public func exactSimilarity() -> UnitInterval {
        var topScore: UnitInterval = 0

        for word in query.array {
            for value in source.searchableArray {
                var score: UnitInterval = contains(text: value, query: word)
                // var score: UnitInterval = smithWatermanSimilarity(text: value, query: word)

                guard score > 0 else {
                    continue
                }

                if score == 1 { return 1 }

                if let searchablePrimaryValue = source.searchablePrimaryValue, value == searchablePrimaryValue {
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

        return topScore
    }

    func contains(text: String, query: String) -> UnitInterval {
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
