// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A parsed and normalized search query split into individual terms.
///
/// Normalized to lowercase and diacritic-free. Space-delimited input keeps the whole phrase as the
/// first element so the matcher can try it before the individual words; comma-delimited does not.
///
/// Space-delimited words must all match; comma-delimited parts are alternatives. ``termGroups``
/// carries that: every group must match, through any one of its terms. A term of ``array`` in no
/// group — the whole phrase — matches the query on its own, so a typo spanning words still finds.
///
/// ```swift
/// let q = DelimitedQuery(string: "haunted stonehenge moon")
/// q.array      // ["haunted stonehenge moon", "haunted", "stonehenge", "moon"]
/// q.termGroups // [["haunted"], ["stonehenge"], ["moon"]]
///
/// let q2 = DelimitedQuery(string: "birds, cats")
/// q2.array      // ["birds", "cats", "bird", "cat"]
/// q2.termGroups // [["birds", "cats", "bird", "cat"]]
/// ```
public struct DelimitedQuery: Sendable, Hashable, Equatable {
    /// The normalized query terms produced by parsing and expanding the input.
    public let array: [String]

    /// The original unmodified input string before normalization.
    public let originalString: String

    /// Every group must match, through any one of its terms. Each term is also in ``array``.
    public let termGroups: [[String]]

    /// The terms of ``array`` in no group, each enough to match the whole query. Empty when there
    /// is one group or none.
    public var wholeQueryTerms: [String] {
        guard termGroups.count > 1 else { return [] }

        let grouped = Set(termGroups.flatMap(\.self))
        return array.filter { !grouped.contains($0) }
    }

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
            termGroups = []
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

        let singular: (String) -> String? = { word in
            // Dropping the trailing s helps matches in some cases; very short words only produce
            // noise ("us" -> "u").
            singularize && word.last == "s" && word.count > 3 ? String(word.dropLast()) : nil
        }

        let singulars = parts.compactMap(singular)
        array = parts + singulars

        if delimiter == " ", split.count > 1 {
            termGroups = split.map { [$0] + [singular($0)].compactMap(\.self) }
        } else {
            termGroups = array.isEmpty ? [] : [array]
        }
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
        termGroups = filtered.isEmpty ? [] : [filtered]
    }

    private init(array: [String], originalString: String, termGroups: [[String]]) {
        self.array = array
        self.originalString = originalString
        self.termGroups = termGroups
    }

    /// This query with `alternatives(group)` added to each group, and to ``array``.
    ///
    /// For widening a query with synonyms without loosening it: an expansion stands in for the
    /// word it came from, not for the whole query.
    public func expanded(by alternatives: ([String]) -> [String]) -> DelimitedQuery {
        var seen = Set(array)
        var added: [String] = []

        let groups = termGroups.map { group in
            let extra = alternatives(group).filter { !group.contains($0) }
            added += extra.filter { seen.insert($0).inserted }
            return group + extra
        }

        return DelimitedQuery(array: array + added, originalString: originalString, termGroups: groups)
    }
}
