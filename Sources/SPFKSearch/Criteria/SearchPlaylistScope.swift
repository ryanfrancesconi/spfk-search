// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// Where a search looks: the whole library, or the playlists the user chose.
public enum SearchPlaylistScope: Sendable, Hashable {
    /// Every ordinary playlist.
    case library

    /// The displayed node, following the sidebar, and/or playlists and groups sorted by
    /// `uuidString`. Never both empty; build it with `init(includesDisplayed:playlists:)`.
    case chosen(includesDisplayed: Bool, playlists: [UUID])

    /// The displayed node alone.
    public static let displayed = SearchPlaylistScope.chosen(includesDisplayed: true, playlists: [])

    /// Sorts and dedupes `playlists`, and is `.library` when nothing is chosen.
    public init(includesDisplayed: Bool, playlists: [UUID]) {
        let ids = Set(playlists).sorted { $0.uuidString < $1.uuidString }

        if !includesDisplayed, ids.isEmpty {
            self = .library
        } else {
            self = .chosen(includesDisplayed: includesDisplayed, playlists: ids)
        }
    }

    public var includesDisplayed: Bool {
        guard case let .chosen(includesDisplayed, _) = self else { return false }
        return includesDisplayed
    }

    public var playlists: [UUID] {
        guard case let .chosen(_, playlists) = self else { return [] }
        return playlists
    }

    /// Whether the search filters the displayed rows in place, rather than building results: the
    /// displayed node alone, or exactly the displayed playlist, with or without it.
    ///
    /// - Parameter displayedPlaylist: the playlist the table shows, `nil` for anything an id cannot
    ///   name, such as a smart playlist or a combined selection.
    public func filtersInPlace(displayedPlaylist: UUID?) -> Bool {
        guard case let .chosen(_, playlists) = self else { return false }
        if playlists.isEmpty { return true }
        guard let displayedPlaylist else { return false }
        return playlists == [displayedPlaylist]
    }
}

// MARK: - JSON

// `{"type": "library"}` or `{"type": "chosen", "displayed": Bool, "playlists": [String]}`.
// Every tag and key is schema.

extension SearchPlaylistScope: Codable {
    /// `nil` for a scope this build does not recognize.
    public init?(json: SearchJSONValue) {
        switch json["type"]?.string {
        case "library":
            self = .library
        case "chosen":
            guard case let .bool(displayed)? = json["displayed"],
                  case let .array(items)? = json["playlists"]
            else { return nil }

            let ids = items.compactMap { $0.string.flatMap(UUID.init(uuidString:)) }
            guard ids.count == items.count else { return nil }
            self = SearchPlaylistScope(includesDisplayed: displayed, playlists: ids)
        default:
            return nil
        }
    }

    public var json: SearchJSONValue {
        switch self {
        case .library:
            .object(["type": .string("library")])
        case let .chosen(includesDisplayed, playlists):
            .object([
                "type": .string("chosen"),
                "displayed": .bool(includesDisplayed),
                "playlists": .array(playlists.map { .string($0.uuidString) }),
            ])
        }
    }

    public init(from decoder: any Decoder) throws {
        let json = try SearchJSONValue(from: decoder)

        guard let scope = SearchPlaylistScope(json: json) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized search scope")
            )
        }

        self = scope
    }

    public func encode(to encoder: any Encoder) throws {
        try json.encode(to: encoder)
    }
}
