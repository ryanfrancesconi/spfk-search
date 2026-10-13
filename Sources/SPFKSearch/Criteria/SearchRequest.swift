// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// What the search field holds: criteria built elsewhere, plus any text typed after them, and
/// where to look.
///
/// Persisted as `{"criteria": …, "text": "…", "scope": …}`, with `criteria` and `scope` absent
/// when nil.
public struct SearchRequest: Sendable, Hashable {
    public var criteria: SearchCriteria?
    public var text: String

    /// `nil` leaves whatever scope the caller already shows.
    public var scope: SearchPlaylistScope?

    public init(criteria: SearchCriteria? = nil, text: String = "", scope: SearchPlaylistScope? = nil) {
        self.criteria = criteria
        self.text = text
        self.scope = scope
    }

    public var isEmpty: Bool {
        (criteria?.isEmpty ?? true) && text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The criteria and the parsed text, both required to match.
    public func combined(resolver: any SearchFieldResolving) -> SearchCriteria {
        let typed = SearchQueryParser.parse(text, resolver: resolver).criteria
        return SearchQueryParser.all([criteria ?? .empty, typed].filter { !$0.isEmpty })
    }
}

extension SearchRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case criteria
        case text
        case scope
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        criteria = try container.decodeIfPresent(SearchCriteria.self, forKey: .criteria)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        scope = try container.decodeIfPresent(SearchJSONValue.self, forKey: .scope).flatMap(SearchPlaylistScope.init(json:))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(criteria, forKey: .criteria)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(scope, forKey: .scope)
    }
}
