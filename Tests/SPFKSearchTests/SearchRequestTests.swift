// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKTesting
import Testing

@testable import SPFKSearch

private struct GenreResolver: SearchFieldResolving {
    func resolveField(named name: String) -> SearchFieldResolution? {
        name.lowercased() == "genre" ? SearchFieldResolution(fieldID: "tag.genre", kind: .text) : nil
    }

    func resolveUnitWord(_ word: String) -> String? { nil }
}

@Suite(.tags(.advancedSearch))
struct SearchRequestTests {
    private let token = SearchCriteria.rule(SearchRule(fieldID: "tag.bpm", op: .greaterThan, operand: .number(120)))
    private let genre = SearchCriteria.rule(SearchRule(fieldID: "tag.genre", op: .contains, operand: .text("ambient")))

    @Test func emptyRequest() {
        #expect(SearchRequest().isEmpty)
        #expect(SearchRequest(criteria: .empty, text: "  ").isEmpty)
        #expect(!SearchRequest(criteria: token).isEmpty)
        #expect(SearchRequest().combined(resolver: GenreResolver()) == .empty)
    }

    @Test func tokenOnly() {
        #expect(SearchRequest(criteria: token).combined(resolver: GenreResolver()) == token)
    }

    @Test func textOnly() {
        #expect(SearchRequest(text: "genre:ambient").combined(resolver: GenreResolver()) == genre)
    }

    @Test func tokenAndTextAreBothRequired() {
        let request = SearchRequest(criteria: token, text: "genre:ambient")
        #expect(request.combined(resolver: GenreResolver()) == .group(.all, [token, genre]))
    }

    @Test func nestedAllGroupsFlatten() {
        let request = SearchRequest(criteria: .group(.all, [token, .text("rain")]), text: "genre:ambient")
        #expect(request.combined(resolver: GenreResolver()) == .group(.all, [token, .text("rain"), genre]))
    }

    @Test func anyGroupStaysNested() {
        let any = SearchCriteria.group(.any, [token, .text("rain")])
        let request = SearchRequest(criteria: any, text: "genre:ambient")
        #expect(request.combined(resolver: GenreResolver()) == .group(.all, [any, genre]))
    }

    @Test func jsonRoundTripKeepsUnknownNodes() throws {
        let unknown = SearchCriteria.unknown(.object(["type": .string("future"), "value": .number(3)]))
        let request = SearchRequest(criteria: .group(.any, [token, unknown]), text: "rain")

        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(SearchRequest.self, from: data) == request)
    }

    @Test func jsonOmitsMissingCriteria() throws {
        let data = try JSONEncoder().encode(SearchRequest(text: "rain"))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["criteria"] == nil)
        #expect(object?["text"] as? String == "rain")
        #expect(try JSONDecoder().decode(SearchRequest.self, from: data) == SearchRequest(text: "rain"))
    }
}
