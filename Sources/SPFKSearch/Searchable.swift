
import Foundation
import FuzzyMatch
import SPFKBase

public protocol Searchable {
    var searchableValue: String { get }
    var searchableArray: [String] { get }
}

extension Searchable {
    public func similarity(to query: String) -> UnitInterval {
        let query = query.normalized
        let parts = query.splitDelimited(delimiter: ",").filter(\.isNotEmpty)

        if #available(macOS 27, *) {
            return fuzzyMatch(to: parts)

        } else {
            return contains(query: parts)
        }
    }
}

extension Searchable {
    func levenshteinDistance(to array: [String], minimumScore: UnitInterval = 0.4) -> UnitInterval {
        guard searchableArray.isNotEmpty, array.isNotEmpty else { return 0 }

        var topScore: UnitInterval = 0

        for value in searchableArray {
            let obj = LevenshteinDistance(string: value)

            for word in array {
                let wordScore = obj.similarity(to: word)

                guard wordScore >= minimumScore else { continue }

                if wordScore > topScore {
                    topScore = wordScore
                }
            }
        }

        return topScore
    }

    @available(macOS 26, iOS 26, *)
    func fuzzyMatch(to array: [String], minimumScore: UnitInterval = 0.9) -> UnitInterval {
        var topScore: UnitInterval = 0
        let matcher = FuzzyMatcher()
        var buffer = matcher.makeBuffer()

        for word in array {
            let query = matcher.prepare(word)

            for value in searchableArray {
                guard let wordScore = matcher.score(value, against: query, buffer: &buffer) else { continue }

                let score = wordScore.score

                guard score >= minimumScore else { continue }

                if score == 1 { return 1 }

                if score > topScore {
                    topScore = score
                }
            }
        }

        return topScore
    }

    // MARK: Simple, unscored

    public func contains(query: [String]) -> UnitInterval {
        for word in query {
            if searchableValue.localizedCaseInsensitiveContains(word) { return 1 }
        }

        return 0
    }
}
