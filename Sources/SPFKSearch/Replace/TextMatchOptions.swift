// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// The text matching toggles a find and replace pass offers.
public struct TextMatchOptions: Sendable, Hashable, Codable {
    /// When `false` the search is case insensitive.
    public var matchCase: Bool

    /// Requires each end of a match to sit on a word boundary under either the alphanumeric
    /// rule or an ICU word break, so `homme` matches inside `l'homme` and `小鼓` inside `大鼓和小鼓`.
    public var wholeWord: Bool

    /// Folds diacritics, full/half width forms and apostrophe/quote style together.
    ///
    /// Ignored when ``useRegex`` is on — `NSRegularExpression` has no equivalent options.
    public var ignoreDiacritics: Bool

    /// Interprets the find text as an ICU regular expression and the replacement as a
    /// template, where `$1`…`$9` refer to capture groups.
    public var useRegex: Bool

    public init(
        matchCase: Bool = false,
        wholeWord: Bool = false,
        ignoreDiacritics: Bool = false,
        useRegex: Bool = false
    ) {
        self.matchCase = matchCase
        self.wholeWord = wholeWord
        self.ignoreDiacritics = ignoreDiacritics
        self.useRegex = useRegex
    }

    /// `true` when the folding toggle has any effect, which excludes regex mode.
    public var foldsCharacterVariants: Bool {
        ignoreDiacritics && !useRegex
    }
}

public enum TextReplacerError: Error, Equatable, LocalizedError {
    case emptyFind
    case invalidPattern(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFind:
            "The find text is empty."
        case let .invalidPattern(message):
            message
        }
    }
}
