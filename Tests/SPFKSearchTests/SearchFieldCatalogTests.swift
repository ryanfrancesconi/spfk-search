// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKTesting
import Testing

@testable import SPFKSearch

@Suite(.tags(.advancedSearch))
struct SearchFieldCatalogTests {
    private let catalog = SearchFieldCatalog(
        entries: [
            .init(id: "tag.title", title: "Title", groupID: "tag.common", groupTitle: "Common", kind: .text),
            .init(id: "file.size", title: "Size", groupID: "file", groupTitle: "File", kind: .number(.bytes)),
            .init(id: "tag.artist", title: "Artist", groupID: "tag.common", groupTitle: "Common", kind: .text),
        ],
        dynamic: { id in
            guard id.hasPrefix("custom.") else { return nil }
            return .init(id: id, title: String(id.dropFirst(7)), groupID: "custom", groupTitle: "Custom", kind: .text)
        }
    )

    @Test func groupsKeepFirstSeenOrder() {
        #expect(catalog.groups.map(\.id) == ["tag.common", "file"])
        #expect(catalog.groups.first?.entries.map(\.id) == ["tag.title", "tag.artist"])
    }

    @Test func dynamicAnswersUnlistedIDs() {
        #expect(catalog.entry(for: "file.size")?.title == "Size")
        #expect(catalog.entry(for: "custom.mood")?.title == "mood")
        #expect(catalog.entry(for: "nothing") == nil)
    }
}
