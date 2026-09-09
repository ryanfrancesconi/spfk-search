// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A prepared find and replace pass over plain text.
///
/// Case folding passes no locale, so a result never depends on the user's system locale —
/// unlike ``String/normalized``, which serves the search index and folds against `.current`.
public struct TextReplacer: Sendable {
    public let find: String
    public let replacement: String
    public let options: TextMatchOptions

    private let regex: NSRegularExpression?
    private let compareOptions: String.CompareOptions
    private let foldsVariants: Bool
    private let canonicalFind: String

    /// - Throws: ``TextReplacerError/emptyFind`` for an empty `find`, or
    ///   ``TextReplacerError/invalidPattern(_:)`` carrying the ICU message for a pattern that
    ///   will not compile.
    public init(find: String, replacement: String, options: TextMatchOptions) throws {
        guard find.isEmpty == false else { throw TextReplacerError.emptyFind }

        self.find = find
        self.replacement = replacement
        self.options = options

        if options.useRegex {
            var regexOptions: NSRegularExpression.Options = []
            if options.matchCase == false { regexOptions.insert(.caseInsensitive) }

            do {
                regex = try NSRegularExpression(pattern: find, options: regexOptions)
            } catch {
                throw TextReplacerError.invalidPattern(error.localizedDescription)
            }

            compareOptions = []
            foldsVariants = false
            canonicalFind = find

        } else {
            regex = nil

            var compare: String.CompareOptions = []
            if options.matchCase == false { compare.insert(.caseInsensitive) }
            if options.ignoreDiacritics { compare.formUnion([.diacriticInsensitive, .widthInsensitive]) }
            compareOptions = compare

            foldsVariants = options.foldsCharacterVariants
            canonicalFind = foldsVariants ? Self.canonical(find) : find
        }
    }

    public func matchCount(in text: String) -> Int {
        matches(in: text).count
    }

    /// - Returns: `nil` when nothing matched, so a caller can skip the write without comparing
    ///   strings.
    public func replacing(_ text: String) -> (result: String, count: Int)? {
        let found = matches(in: text)
        guard found.isEmpty == false else { return nil }

        var result = ""
        var cursor = text.startIndex

        for match in found {
            result += text[cursor ..< match.range.lowerBound]
            result += match.replacement
            cursor = match.range.upperBound
        }

        result += text[cursor...]

        return (result, found.count)
    }

    // MARK: - Matching

    private struct Match {
        let range: Range<String.Index>
        let replacement: String
    }

    private func matches(in text: String) -> [Match] {
        guard text.isEmpty == false else { return [] }

        if let regex {
            return regexMatches(in: text, regex: regex)
        }

        return literalMatches(in: text, foldingVariants: foldsVariants)
    }

    private func literalMatches(in text: String, foldingVariants: Bool) -> [Match] {
        // Quote style and half-width kana have no Foundation compare option, so they are
        // canonicalized in a character-for-character pre-pass and the found ranges are mapped
        // back onto the original text.
        let haystack = foldingVariants ? Self.canonical(text) : text
        let indexMap = foldingVariants ? Self.indexMap(from: haystack, to: text) : nil

        if foldingVariants, indexMap == nil {
            return literalMatches(in: text, foldingVariants: false)
        }

        let needle = foldingVariants ? canonicalFind : find
        let boundaries = options.wholeWord ? WordBoundaries(text: text) : nil

        var found: [Match] = []
        var searchStart = haystack.startIndex

        while searchStart < haystack.endIndex,
              let range = haystack.range(
                  of: needle,
                  options: compareOptions,
                  range: searchStart ..< haystack.endIndex,
                  locale: nil
              ) {
            let mapped = Self.mapping(range, through: indexMap)

            if let mapped, boundaries?.isWholeWord(mapped) != false {
                found.append(Match(range: mapped, replacement: replacement))
            }

            searchStart = range.upperBound > range.lowerBound
                ? range.upperBound
                : haystack.index(after: range.lowerBound)
        }

        return found
    }

    private func regexMatches(in text: String, regex: NSRegularExpression) -> [Match] {
        let boundaries = options.wholeWord ? WordBoundaries(text: text) : nil
        let full = NSRange(text.startIndex ..< text.endIndex, in: text)

        return regex.matches(in: text, options: [], range: full).compactMap { result in
            guard let range = Range(result.range, in: text) else { return nil }
            guard boundaries?.isWholeWord(range) != false else { return nil }

            let expanded = regex.replacementString(
                for: result,
                in: text,
                offset: 0,
                template: replacement
            )

            return Match(range: range, replacement: expanded)
        }
    }

    // MARK: - Character variants

    private static let apostrophes: Set<Character> = ["'", "\u{2018}", "\u{2019}"]
    private static let quotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]

    /// Collapses the variants no `CompareOptions` value reaches: curly quotes onto their ASCII
    /// form, and half-width kana onto the precomposed full-width form.
    ///
    /// The width transform is what makes `ﾄﾞﾗﾑ` match `ドラム` — `.widthInsensitive` alone does,
    /// but paired with `.diacriticInsensitive` it strips the half-width voiced mark from one side
    /// only and the two stop matching (measured 2026-09-09).
    private static func canonical(_ text: String) -> String {
        let quoted = String(text.map { character in
            if apostrophes.contains(character) { return "'" }
            if quotes.contains(character) { return "\"" }
            return character
        })

        let mutable = NSMutableString(string: quoted)

        guard CFStringTransform(mutable as CFMutableString, nil, kCFStringTransformFullwidthHalfwidth, true) else {
            return quoted
        }

        return mutable as String
    }

    private static func mapping(
        _ range: Range<String.Index>,
        through map: [String.Index: String.Index]?
    ) -> Range<String.Index>? {
        guard let map else { return range }
        guard let lower = map[range.lowerBound], let upper = map[range.upperBound] else { return nil }
        return lower ..< upper
    }

    /// Maps each index of the canonicalized string onto the index of the original at the same
    /// character offset. `nil` when the two do not have the same character count, which would
    /// make every splice land in the wrong place.
    private static func indexMap(from folded: String, to original: String) -> [String.Index: String.Index]? {
        var map: [String.Index: String.Index] = [:]
        var foldedIndex = folded.startIndex
        var originalIndex = original.startIndex

        while foldedIndex < folded.endIndex, originalIndex < original.endIndex {
            map[foldedIndex] = originalIndex
            foldedIndex = folded.index(after: foldedIndex)
            originalIndex = original.index(after: originalIndex)
        }

        guard foldedIndex == folded.endIndex, originalIndex == original.endIndex else { return nil }

        map[folded.endIndex] = original.endIndex

        return map
    }
}
