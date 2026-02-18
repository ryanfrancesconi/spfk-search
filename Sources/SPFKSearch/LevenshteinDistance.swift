import Foundation
import SPFKBase

public enum SearchMode: Sendable, Equatable {
    case levenshtein
}

public struct LevenshteinDistance: Sendable, Hashable, Equatable {
    let string: String

    public init(string: String) {
        self.string = string.normalized
    }

    /// Calculates the Levenshtein distance to another string.
    func distance(to query: String) -> Int {
        let other = query.normalized

        let sCount = string.count
        let oCount = other.count

        if sCount == 0 { return oCount }
        if oCount == 0 { return sCount }

        let sChars = Array(string)
        let oChars = Array(other)

        var prevRow = Array(0 ... oCount)
        var currRow = [Int](repeating: 0, count: oCount + 1)

        for i in 1 ... sCount {
            currRow[0] = i

            for j in 1 ... oCount {
                let cost = sChars[i - 1] == oChars[j - 1] ? 0 : 1
                currRow[j] = min(
                    currRow[j - 1] + 1, // Insertion
                    prevRow[j] + 1, // Deletion
                    prevRow[j - 1] + cost // Substitution
                )
            }

            prevRow = currRow
        }

        return prevRow[oCount]
    }

    /// - Parameter other: string to compare to
    /// - Returns: a similarity score between 0.0 and 1.0.
    public func similarity(to other: String) -> UnitInterval {
        let distance = Double(
            distance(to: other)
        )

        let maxLength = Double(
            max(string.count, other.count)
        )

        guard maxLength > 0 else { return 1.0 }

        return 1.0 - (distance / maxLength)
    }
}
