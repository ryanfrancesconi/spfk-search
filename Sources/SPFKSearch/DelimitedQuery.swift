// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A parsed and normalized search query split into individual terms.
///
/// Accepts raw user input and produces an array of normalized, lowercase,
/// diacritic-free search terms. Automatically detects comma vs space delimiters
/// and appends singular variants for words ending in "s" to improve recall.
///
/// For space-delimited input the full phrase is kept as the first element
/// so the matcher can try whole-phrase matching before individual words.
/// For comma-delimited input only the individual terms are used.
///
/// ```swift
/// let q = DelimitedQuery(string: "haunted stonehenge moon")
/// q.array // ["haunted stonehenge moon", "haunted", "stonehenge", "moon"]
///
/// let q2 = DelimitedQuery(string: "birds, cats")
/// q2.array // ["birds", "cats", "bird", "cat"]
/// ```
public struct DelimitedQuery: Sendable, Hashable, Equatable {
    /// The normalized query terms produced by parsing and expanding the input.
    public let array: [String]

    /// The original unmodified input string before normalization.
    public let originalString: String

    /// Creates a query by parsing and normalizing the given string.
    ///
    /// - Parameter string: Raw user input. Commas trigger comma-delimited mode;
    ///   otherwise the string is split on spaces. Empty input produces an empty array.
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
