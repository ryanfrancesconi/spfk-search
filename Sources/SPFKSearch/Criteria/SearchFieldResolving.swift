// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A product's field vocabulary, as the parser sees it.
public protocol SearchFieldResolving: Sendable {
    /// The field a typed name means, matched case-insensitively, or `nil` when it names none.
    func resolveField(named name: String) -> SearchFieldResolution?

    /// The field a unit word infers from an adjacent number (`120 bpm`), or `nil`.
    func resolveUnitWord(_ word: String) -> String?
}

public struct SearchFieldResolution: Sendable, Hashable {
    public let fieldID: String
    public let kind: SearchFieldKind

    public init(fieldID: String, kind: SearchFieldKind) {
        self.fieldID = fieldID
        self.kind = kind
    }
}
