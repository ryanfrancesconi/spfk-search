// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

public struct DelimitedQuery: Sendable, Hashable, Equatable {
    public let array: [String]
    public let originalString: String

    public init(string: String) {
        guard string.isNotEmpty else {
            array = []
            originalString = ""
            return
        }

        originalString = string

        let delimiter = string.contains(",") ? "," : " "
        
        let delimiterCount = string.ranges(of: delimiter).count
        let string = string.normalized
        
        var parts: [String] = delimiter == " " ? [string] : []

        if delimiterCount > 0 {
            parts += string
                .splitDelimited(delimiter: delimiter)
                .filter(\.isNotEmpty)
        }

        // if a word ends with an s, drop the s and add a singular(ish) word to the query
        // this seems to help matches in some cases
        let singulars: [String] = parts
            .filter { $0.last == "s" }
            .map { String($0.dropLast()) }

        if singulars.isNotEmpty {
            parts += singulars
        }

        array = parts
    }
}
