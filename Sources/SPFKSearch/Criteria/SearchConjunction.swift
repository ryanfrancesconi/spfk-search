// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// How a group combines its children. The raw values are persisted.
public enum SearchConjunction: String, Sendable, Hashable, CaseIterable {
    case all
    case any

    /// None of the children match: `NOT` in the text syntax.
    case none
}
