// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// One choice of an enumeration field.
public struct SearchEnumOption: Sendable, Hashable {
    /// Persisted in a rule's operand.
    public let value: String
    public let title: String

    public init(value: String, title: String) {
        self.value = value
        self.title = title
    }
}
