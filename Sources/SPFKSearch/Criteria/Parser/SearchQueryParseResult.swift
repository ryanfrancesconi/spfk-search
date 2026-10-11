// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

public struct SearchQueryParseResult: Sendable, Hashable {
    public let criteria: SearchCriteria
    public let diagnostics: [SearchQueryDiagnostic]
}

/// A problem in typed text. The text it covers is still searched, as free text.
public struct SearchQueryDiagnostic: Sendable, Hashable {
    public enum Kind: Error, Sendable, Hashable {
        /// `name:value` where the name is no field.
        case unknownField

        /// A value the field's kind cannot read, such as `2m` for a date.
        case invalidValue

        /// An operator the field's kind does not offer, such as `>` on text.
        case invalidOperator

        case unbalancedParenthesis
    }

    public let kind: Kind

    /// Into the parsed text.
    public let range: Range<String.Index>
}
