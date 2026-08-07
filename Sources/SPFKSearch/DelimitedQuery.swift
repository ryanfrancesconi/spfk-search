// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A parsed and normalized search query split into individual terms.
///
/// Normalized to lowercase and diacritic-free. Space-delimited input keeps the whole phrase as the
/// first element so the matcher can try it before the individual words; comma-delimited does not.
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
    /// - Parameters:
    ///   - string: Raw user input. Commas trigger comma-delimited mode;
    ///     otherwise the string is split on spaces. Empty input produces an empty array.
    ///   - singularize: When `true` (default), appends de-pluralized variants for words
    ///     ending in "s" to improve recall for user search queries. Pass `false` when the
    ///     input is a metadata corpus rather than a user query — singularization can cause
    ///     false prefix collisions (e.g. "bees" → "bee" matching catID "BEEP").
    public init(string: String, singularize: Bool = true) {
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

        if singularize {
            // if a word ends with an s, drop the s and add a singular(ish) word to the query
            // this seems to help matches in some cases. guard against very short words
            // where dropping the trailing s produces noise (e.g. "us" -> "u")
            let singulars: [String] = parts
                .filter { $0.last == "s" && $0.count > 3 }
                .map { String($0.dropLast()) }

            if singulars.isNotEmpty {
                parts += singulars
            }
        }

        array = parts
    }

    /// Creates a query directly from a pre-built array of normalized terms.
    ///
    /// Bypasses parsing and singularization. `originalString` becomes the joined terms.
    ///
    /// - Parameter terms: Pre-normalized search terms. Empty terms are filtered out.
    public init(terms: [String]) {
        let filtered = terms.filter(\.isNotEmpty)
        array = filtered
        originalString = filtered.joined(separator: " ")
    }
}
