// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A product's search fields as a UI lists them: id, title, group and kind.
public struct SearchFieldCatalog: Sendable {
    public struct Entry: Sendable, Hashable {
        public let id: String
        public let title: String
        public let groupID: String
        public let groupTitle: String
        public let kind: SearchFieldKind

        public init(id: String, title: String, groupID: String, groupTitle: String, kind: SearchFieldKind) {
            self.id = id
            self.title = title
            self.groupID = groupID
            self.groupTitle = groupTitle
            self.kind = kind
        }
    }

    public struct Group: Sendable, Hashable {
        public let id: String
        public let title: String
        public let entries: [Entry]
    }

    public let entries: [Entry]

    /// Answers ids not in `entries`, such as a product's `custom.<name>` fields.
    public let dynamic: @Sendable (String) -> Entry?

    private let index: [String: Int]

    public init(entries: [Entry], dynamic: @escaping @Sendable (String) -> Entry? = { _ in nil }) {
        self.entries = entries
        self.dynamic = dynamic
        index = Dictionary(entries.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func entry(for id: String) -> Entry? {
        index[id].map { entries[$0] } ?? dynamic(id)
    }

    /// The entries by group, groups in the order they first appear.
    public var groups: [Group] {
        var order: [String] = []
        var byGroup: [String: [Entry]] = [:]

        for entry in entries {
            if byGroup[entry.groupID] == nil { order.append(entry.groupID) }
            byGroup[entry.groupID, default: []].append(entry)
        }

        return order.compactMap { id in
            guard let members = byGroup[id], let first = members.first else { return nil }
            return Group(id: id, title: first.groupTitle, entries: members)
        }
    }
}
