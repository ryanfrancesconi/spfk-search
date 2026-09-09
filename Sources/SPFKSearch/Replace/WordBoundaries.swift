// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// Whole-word tests for one string, under two boundary rules at once.
///
/// Neither rule alone serves every shipped language: the alphanumeric rule never fires inside a
/// CJK run, and the ICU rule keeps `l'homme` and `drum's` as single words. A position is a
/// boundary when *either* rule says so.
struct WordBoundaries {
    private let text: String
    private let icuBreaks: Set<String.Index>

    init(text: String) {
        self.text = text

        var breaks: Set<String.Index> = []

        text.enumerateSubstrings(
            in: text.startIndex ..< text.endIndex,
            options: [.byWords, .substringNotRequired]
        ) { _, range, _, _ in
            breaks.insert(range.lowerBound)
            breaks.insert(range.upperBound)
        }

        icuBreaks = breaks
    }

    func isWholeWord(_ range: Range<String.Index>) -> Bool {
        isBoundaryBefore(range.lowerBound) && isBoundaryAfter(range.upperBound)
    }

    private func isBoundaryBefore(_ index: String.Index) -> Bool {
        guard index > text.startIndex else { return true }
        guard Self.isWordCharacter(text[text.index(before: index)]) else { return true }
        return icuBreaks.contains(index)
    }

    private func isBoundaryAfter(_ index: String.Index) -> Bool {
        guard index < text.endIndex else { return true }
        guard Self.isWordCharacter(text[index]) else { return true }
        return icuBreaks.contains(index)
    }

    /// Underscore counts as a word character, as it does in every editor's whole-word search.
    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
