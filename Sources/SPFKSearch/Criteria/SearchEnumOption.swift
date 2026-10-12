// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

/// One choice of an enumeration field.
public struct SearchEnumOption: Sendable, Hashable {
    /// Persisted in a rule's operand.
    public let value: String
    public let title: String

    /// A color drawn beside the title where the choice is a color.
    public let swatch: HexColor?

    public init(value: String, title: String, swatch: HexColor? = nil) {
        self.value = value
        self.title = title
        self.swatch = swatch
    }
}
