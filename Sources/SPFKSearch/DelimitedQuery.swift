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
        let string = string.normalized

        let split = string.splitDelimited(delimiter: delimiter).filter(\.isNotEmpty)

        // For space-delimited queries, keep the full string as the first element
        // so the matcher can try the whole phrase. For comma-delimited, only use parts.
        var parts: [String] = []
        if delimiter == " " {
            parts.append(string)
            if split.count > 1 {
                parts += split
            }
        } else {
            parts = split
        }

        // if a word ends with an s, drop the s and add a singular(ish) word to the query
        // this seems to help matches in some cases. guard against very short words
        // where dropping the trailing s produces noise (e.g. "us" -> "u")
        let singulars: [String] = parts
            .filter { $0.last == "s" && $0.count > 3 }
            .map { String($0.dropLast()) }

        if singulars.isNotEmpty {
            parts += singulars
        }

        array = parts
    }
}
