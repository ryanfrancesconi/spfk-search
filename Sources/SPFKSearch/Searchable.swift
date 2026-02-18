// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

public protocol Searchable {
    var searchableArray: [String] { get }
    var searchablePrimaryValue: String? { get }
}

extension Searchable {
    public var searchablePrimaryValue: String? { nil }
}

extension Searchable {
    public func similarity(to query: String, minimumScore: UnitInterval = 0.9) -> UnitInterval {
        let delimiter = query.contains(",") ? "," : " "
        let query = query.normalized
        var parts = query.splitDelimited(delimiter: delimiter).filter(\.isNotEmpty)
        let singulars = parts.filter { $0.last == "s" }.map { String($0.dropLast()) }

        if singulars.isNotEmpty {
            parts += singulars
        }

        // Log.debug(parts)

        return if #available(macOS 26, iOS 26, *) {
            fuzzyMatch(to: parts, minimumScore: minimumScore)
        } else {
            contains(query: parts, minimumScore: minimumScore)
        }
    }
}

extension Searchable {
    @available(macOS 26, iOS 26, *)
    public func fuzzyMatch(to array: [String], minimumScore: UnitInterval) -> UnitInterval {
        var topScore: UnitInterval = 0
        let matcher = FuzzyMatcher()
        var buffer = matcher.makeBuffer()

        for word in array {
            let query = matcher.prepare(word)

            for value in searchableArray {
                guard let wordScore = matcher.score(value, against: query, buffer: &buffer) else { continue }

                var score = wordScore.score

                // Log.debug("\(value) = \(wordScore)")

                if let searchablePrimaryValue, value == searchablePrimaryValue {
                    score += 0.2
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

extension Searchable {
    // MARK: Simple, localizedStandardRange based

    public func contains(query: [String], minimumScore: UnitInterval = 0.5) -> UnitInterval {
        var topScore: UnitInterval = 0

        for word in query {
            for value in searchableArray {
                var score: UnitInterval = contains(text: value, query: word)

                if score == 1 { return 1 }

                if let searchablePrimaryValue, value == searchablePrimaryValue {
                    score += 0.2
                }
                
                guard score >= minimumScore else { continue }

                if score > topScore {
                    topScore = score

                    Log.debug("topScore", topScore, value)
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

        let textCount = Double(text.count)
        let queryCount = Double(query.count)

        // 1. Proximity Score (closer to 0 is better)
        // Range starts from 0 to (textCount - queryCount)
        let position = Double(text.distance(from: text.startIndex, to: range.lowerBound))
        let maxPosition = textCount - queryCount + 1

        // Lower position = higher score
        let proximityScore = 1.0 - (position / maxPosition)

        // 2. Length Score (longer query is better)
        let lengthScore = queryCount / textCount

        // 3. Combined Score (Weighted combination)
        // Adjust weights, prioritize position over length
        let finalScore = (0.9 * proximityScore) + (0.1 * lengthScore)

        return finalScore.clamped(to: 0 ... 1)
    }
}
