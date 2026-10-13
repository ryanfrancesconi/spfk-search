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

    /// The playlists the rules name, at any depth: what has to be resolved before compiling.
    public var referencedPlaylistIDs: Set<UUID> {
        switch self {
        case let .group(_, children): children.reduce(into: []) { $0.formUnion($1.referencedPlaylistIDs) }
        case let .rule(rule): if case let .playlists(ids) = rule.operand { Set(ids) } else { [] }
        case .text, .unknown: []
        }
    }
}
