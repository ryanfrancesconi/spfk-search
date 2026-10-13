// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKTesting
import Testing

@testable import SPFKSearch

@Suite(.tags(.advancedSearch))
struct SearchCriteriaJSONTests {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private func scope(_ json: String) throws -> SearchPlaylistScope? {
        SearchPlaylistScope(json: try JSONDecoder().decode(SearchJSONValue.self, from: Data(json.utf8)))
    }

    // MARK: - Zero and one are numbers

    @Test(arguments: [
        (
            SearchCriteria.rule(SearchRule(fieldID: "file.modified", op: .inTheLast, operand: .relative(amount: 1, unit: .day))),
            #"{"field":"file.modified","operand":{"amount":1,"type":"relative","unit":"day"},"operator":"inTheLast","type":"rule"}"#
        ),
        (
            .rule(SearchRule(fieldID: "rating", op: .is, operand: .number(0))),
            #"{"field":"rating","operand":{"type":"number","value":0},"operator":"is","type":"rule"}"#
        ),
        (
            .unknown(.object(["type": .string("future"), "value": .number(1)])),
            #"{"type":"future","value":1}"#
        ),
    ])
    func zeroAndOneRoundTripAsNumbers(criteria: SearchCriteria, json: String) throws {
        #expect(String(decoding: try Self.encoder.encode(criteria), as: UTF8.self) == json)

        let decoded = try JSONDecoder().decode(SearchCriteria.self, from: Data(json.utf8))
        #expect(decoded == criteria)
        #expect(String(decoding: try Self.encoder.encode(decoded), as: UTF8.self) == json)
    }

    @Test func aJSONBoolStaysABool() throws {
        let decoded = try JSONDecoder().decode(SearchJSONValue.self, from: Data(#"[true, 1, false, 0]"#.utf8))
        #expect(decoded == .array([.bool(true), .number(1), .bool(false), .number(0)]))
    }

    // MARK: - Scope

    @Test func aChosenScopeNamingNothingDecodesAsTheLibrary() throws {
        #expect(try scope(#"{"type":"chosen","displayed":false,"playlists":[]}"#) == .library)
    }

    @Test func aDecodedScopeIsSortedAndDeduplicated() throws {
        let a = "00000000-0000-0000-0000-00000000000A"
        let b = "00000000-0000-0000-0000-00000000000B"
        let decoded = try scope(#"{"type":"chosen","displayed":true,"playlists":["\#(b)","\#(a)","\#(b)"]}"#)

        #expect(decoded == .chosen(includesDisplayed: true, playlists: [a, b].compactMap(UUID.init(uuidString:))))
    }

    @Test func aScopeWithABadUUIDIsUnrecognized() throws {
        #expect(try scope(#"{"type":"chosen","displayed":false,"playlists":["not a uuid"]}"#) == nil)

        let request = try JSONDecoder().decode(
            SearchRequest.self,
            from: Data(#"{"text":"rain","scope":{"type":"chosen","displayed":true,"playlists":["nope"]}}"#.utf8)
        )
        #expect(request.scope == nil)
        #expect(request.text == "rain")
    }
}
