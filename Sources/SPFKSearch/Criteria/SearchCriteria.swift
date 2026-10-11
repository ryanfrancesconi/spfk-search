// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A search, as a tree of field rules and free text.
///
/// Persisted by smart playlists, so its encoded form is schema: see `SearchCriteria+JSON.swift`.
public indirect enum SearchCriteria: Sendable, Hashable {
    case group(SearchConjunction, [SearchCriteria])
    case rule(SearchRule)

    /// Free text, matched the way the search field always has.
    case text(String)

    /// A node written by a newer or other product. Matches nothing and re-encodes unchanged.
    case unknown(SearchJSONValue)

    /// Matches everything.
    public static let empty = SearchCriteria.group(.all, [])

    /// No rules and no text, at any depth.
    public var isEmpty: Bool {
        switch self {
        case let .group(_, children): children.allSatisfy(\.isEmpty)
        case .rule, .unknown: false
        case let .text(text): text.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}
