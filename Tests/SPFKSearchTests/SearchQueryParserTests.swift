// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKTesting
import Testing

@testable import SPFKSearch

/// A small vocabulary covering every kind, standing in for a product's registry.
private struct StubResolver: SearchFieldResolving {
    static let fields: [String: SearchFieldResolution] = [
        "bpm": .init(fieldID: "tag.bpm", kind: .number(.bpm)),
        "tempo": .init(fieldID: "tag.bpm", kind: .number(.bpm)),
        "key": .init(fieldID: "tag.initialKey", kind: .text),
        "lufs": .init(fieldID: "tag.loudnessIntegrated", kind: .number(.lufs)),
        "artist": .init(fieldID: "tag.artist", kind: .text),
        "genre": .init(fieldID: "tag.genre", kind: .text),
        "rating": .init(fieldID: "rating", kind: .rating),
        "duration": .init(fieldID: "format.duration", kind: .duration),
        "date": .init(fieldID: "tag.date", kind: .date),
        "size": .init(fieldID: "file.size", kind: .number(.bytes)),
        "sample rate": .init(fieldID: "format.sampleRate", kind: .number(.hertz)),
        "color": .init(fieldID: "color", kind: .color),
        "type": .init(fieldID: "file.type", kind: .enumeration([
            .init(value: "wav", title: "WAV"), .init(value: "mp3", title: "MP3"),
        ])),
        "dirty": .init(fieldID: "state.dirty", kind: .bool),
        "keywords": .init(fieldID: "keywords", kind: .list),
    ]

    func resolveField(named name: String) -> SearchFieldResolution? {
        Self.fields[name.lowercased()]
    }

    func resolveUnitWord(_ word: String) -> String? {
        switch word.lowercased() {
        case "bpm", "tempo": "tag.bpm"
        case "lufs": "tag.loudnessIntegrated"
        default: nil
        }
    }
}

@Suite(.tags(.advancedSearch))
struct SearchQueryParserTests {
    private func parse(_ text: String) -> SearchQueryParseResult {
        SearchQueryParser.parse(text, resolver: StubResolver())
    }

    private func criteria(_ text: String) -> SearchCriteria {
        parse(text).criteria
    }

    private func rule(_ field: String, _ op: SearchOperator, _ operand: SearchOperand = .none) -> SearchCriteria {
        .rule(SearchRule(fieldID: field, op: op, operand: operand))
    }

    // MARK: - Legacy forms

    @Test func emptyTextIsTheEmptyCriteria() {
        let result = parse("")
        #expect(result.criteria == .empty)
        #expect(result.criteria.isEmpty)
        #expect(result.diagnostics.isEmpty)
    }

    @Test(arguments: [
        ("piano", SearchCriteria.text("piano")),
        ("bpm:120", .rule(SearchRule(fieldID: "tag.bpm", op: .contains, operand: .text("120")))),
        ("key:Cm", .rule(SearchRule(fieldID: "tag.initialKey", op: .contains, operand: .text("Cm")))),
        ("lufs:-14", .rule(SearchRule(fieldID: "tag.loudnessIntegrated", op: .contains, operand: .text("-14")))),
        ("rating: 4 ", .rule(SearchRule(fieldID: "rating", op: .contains, operand: .text("4")))),
        ("bpm:", .text("bpm:")),
        ("120 bpm", .rule(SearchRule(fieldID: "tag.bpm", op: .contains, operand: .text("120")))),
        ("bpm 120", .rule(SearchRule(fieldID: "tag.bpm", op: .contains, operand: .text("120")))),
        ("-14 lufs", .rule(SearchRule(fieldID: "tag.loudnessIntegrated", op: .contains, operand: .text("-14")))),
        ("128 tempo", .rule(SearchRule(fieldID: "tag.bpm", op: .contains, operand: .text("128")))),
        ("piano bpm", .group(.all, [.text("piano"), .text("bpm")])),
    ])
    func legacyFormsParseAsBefore(text: String, expected: SearchCriteria) {
        #expect(criteria(text) == expected)
    }

    @Test func colonClausesAndFreeTextKeepTheirOrder() {
        #expect(criteria("bpm:120 artist:arca") == .group(.all, [
            rule("tag.bpm", .contains, .text("120")), rule("tag.artist", .contains, .text("arca")),
        ]))
        #expect(criteria("piano bpm:120") == .group(.all, [.text("piano"), rule("tag.bpm", .contains, .text("120"))]))
        #expect(criteria("kick 120 bpm") == .group(.all, [.text("kick"), rule("tag.bpm", .contains, .text("120"))]))
    }

    @Test func anUnknownFieldIsSearchedAsTextAndReported() {
        let result = parse("unknown:value")
        #expect(result.criteria == .text("unknown:value"))
        #expect(result.diagnostics.map(\.kind) == [.unknownField])

        // A number before the colon is not a misspelled field.
        #expect(parse("10:30").diagnostics.isEmpty)
        #expect(parse("10:30").criteria == .text("10:30"))
    }

    // MARK: - Grammar

    @Test func orBindsLooserThanJuxtaposition() {
        #expect(criteria("a OR b c") == .group(.any, [.text("a"), .group(.all, [.text("b"), .text("c")])]))
    }

    @Test func keywordsAreUpperCaseOnly() {
        #expect(criteria("NOT a") == .group(.none, [.text("a")]))
        #expect(criteria("a not b") == .group(.all, [.text("a"), .text("not"), .text("b")]))
        #expect(criteria("rain or leaves") == .group(.all, [.text("rain"), .text("or"), .text("leaves")]))
        #expect(criteria("a AND b") == .group(.all, [.text("a"), .text("b")]))
    }

    @Test func aDashNegatesWordsButNotNumbers() {
        #expect(criteria("-sunset") == .group(.none, [.text("sunset")]))
        #expect(criteria("-artist:x") == .group(.none, [rule("tag.artist", .contains, .text("x"))]))
        #expect(criteria("-14") == .text("-14"))
        #expect(criteria("-\"rain on\"") == .group(.none, [.text("rain on")]))
    }

    @Test func parenthesesGroup() {
        #expect(criteria("(a OR b) bpm > 120") == .group(.all, [
            .group(.any, [.text("a"), .text("b")]), rule("tag.bpm", .greaterThan, .number(120)),
        ]))
    }

    @Test func anUnclosedParenthesisIsReportedAndStillParses() {
        let result = parse("(a b")
        #expect(result.criteria == .group(.all, [.text("a"), .text("b")]))
        #expect(result.diagnostics.map(\.kind) == [.unbalancedParenthesis])
    }

    @Test func quotesGroupValuesAndFieldNames() {
        #expect(criteria("genre == \"deep house\"") == rule("tag.genre", .is, .text("deep house")))
        #expect(criteria("\"Sample Rate\" >= 44.1k") == rule("format.sampleRate", .greaterOrEqual, .number(44100)))
    }

    // MARK: - Operators and typed operands

    @Test func symbolsMapToOperatorsByKind() {
        #expect(criteria("genre != ambient") == rule("tag.genre", .isNot, .text("ambient")))
        #expect(criteria("genre ^= amb") == rule("tag.genre", .beginsWith, .text("amb")))
        #expect(criteria("genre $= ent") == rule("tag.genre", .endsWith, .text("ent")))
        #expect(criteria("genre !: noise") == rule("tag.genre", .doesNotContain, .text("noise")))
        #expect(criteria("bpm>120") == rule("tag.bpm", .greaterThan, .number(120)))
        #expect(criteria("bpm == 120") == rule("tag.bpm", .is, .number(120)))
        #expect(criteria("rating >= 3") == rule("rating", .greaterOrEqual, .number(3)))
        #expect(criteria("bpm == 100..120") == rule("tag.bpm", .between, .range(.number(100), .number(120))))
    }

    @Test func unitLettersAreTypedByTheFieldsKind() {
        #expect(criteria("duration < 2m") == rule("format.duration", .lessThan, .number(120)))
        #expect(criteria("duration < 5s") == rule("format.duration", .lessThan, .number(5)))
        #expect(criteria("size > 10MB") == rule("file.size", .greaterThan, .number(10_000_000)))

        let onDate = parse("date > 2m")
        #expect(onDate.criteria == .text("date > 2m"))
        #expect(onDate.diagnostics.map(\.kind) == [.invalidValue])
    }

    @Test func datesKeepTheirPrecision() throws {
        let april = try #require(SearchDate(year: 2019, month: 4))
        let year = try #require(SearchDate(year: 2019))
        let next = try #require(SearchDate(year: 2020))

        #expect(criteria("date == 2019-04") == rule("tag.date", .is, .date(april)))
        #expect(criteria("date < 2019") == rule("tag.date", .lessThan, .date(year)))
        #expect(criteria("date == 2019..2020") == rule("tag.date", .between, .range(.date(year), .date(next))))
        #expect(criteria("date in last 30d") == rule("tag.date", .inTheLast, .relative(amount: 30, unit: .day)))
        #expect(criteria("date in this year") == rule("tag.date", .inThisPeriod, .period(.year)))
    }

    @Test func wordOperators() {
        #expect(criteria("genre is empty") == rule("tag.genre", .isEmpty))
        #expect(criteria("genre is not empty") == rule("tag.genre", .isNotEmpty))
        #expect(criteria("color in (red, Blue)") == rule("color", .isAnyOf, .list(["red", "blue"])))
        #expect(criteria("type in (WAV, mp3)") == rule("file.type", .isAnyOf, .list(["wav", "mp3"])))
        #expect(criteria("dirty == true") == rule("state.dirty", .isTrue))
        #expect(criteria("dirty != true") == rule("state.dirty", .isFalse))

        // Only after a name the resolver knows.
        #expect(criteria("rain in leaves") == .group(.all, [.text("rain"), .text("in"), .text("leaves")]))
    }

    @Test(arguments: ["genre > 3", "bpm in last 30d", "color == mauve", "bpm ^= 1", "dirty == maybe"])
    func anInvalidClauseIsReportedAndSearchedAsText(text: String) {
        let result = parse(text)
        #expect(result.criteria == .text(text))
        #expect(result.diagnostics.count == 1)
    }

    // MARK: - Persisted form

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    @Test func criteriaRoundTripThroughJSON() throws {
        let date = try #require(SearchDate(year: 2019, month: 4, day: 12))
        let value = SearchCriteria.group(.all, [
            .text("rain"),
            .group(.any, [
                rule("tag.bpm", .between, .range(.number(100), .number(120.5))),
                rule("tag.date", .lessThan, .date(date)),
                rule("file.modified", .inTheLast, .relative(amount: 30, unit: .day)),
            ]),
            .group(.none, [rule("color", .isAnyOf, .list(["red", "blue"]))]),
            rule("playlist", .is, .playlist(UUID())),
            rule("state.dirty", .isTrue),
        ])

        let data = try Self.encoder.encode(value)
        #expect(try JSONDecoder().decode(SearchCriteria.self, from: data) == value)
    }

    @Test func aRuleWithAnUnknownOperatorSurvivesARoundTripUnchanged() throws {
        let json = #"{"children":[{"field":"tag.bpm","operand":{"type":"number","value":120},"operator":"isRoughly","type":"rule"},{"type":"text","value":"rain"}],"conjunction":"all","type":"group"}"#

        let decoded = try JSONDecoder().decode(SearchCriteria.self, from: Data(json.utf8))

        guard case let .group(.all, children) = decoded, case .unknown = children.first else {
            Issue.record("expected an unknown node, got \(decoded)")
            return
        }
        #expect(children.last == .text("rain"))
        #expect(String(decoding: try Self.encoder.encode(decoded), as: UTF8.self) == json)
    }

    @Test func theWrittenFormatIsPinned() throws {
        let json = #"""
        {"type":"group","conjunction":"any","children":[
            {"type":"rule","field":"tag.genre","operator":"is","operand":{"type":"text","value":"ambient"}},
            {"type":"rule","field":"tag.date","operator":"between","operand":{"type":"range",
                "lower":{"type":"date","value":{"year":2019}},"upper":{"type":"date","value":{"year":2020,"month":6}}}},
            {"type":"rule","field":"file.modified","operator":"inThisPeriod","operand":{"type":"period","unit":"week"}},
            {"type":"rule","field":"rating","operator":"isEmpty","operand":{"type":"none"}}
        ]}
        """#

        let decoded = try JSONDecoder().decode(SearchCriteria.self, from: Data(json.utf8))
        let year = try #require(SearchDate(year: 2019))
        let june = try #require(SearchDate(year: 2020, month: 6))

        #expect(decoded == .group(.any, [
            rule("tag.genre", .is, .text("ambient")),
            rule("tag.date", .between, .range(.date(year), .date(june))),
            rule("file.modified", .inThisPeriod, .period(.week)),
            rule("rating", .isEmpty),
        ]))
    }

    // MARK: - Dates

    @Test func aTimestampComparesAsItsDay() throws {
        let day = try #require(SearchDate(year: 2019, month: 4, day: 12))
        #expect(SearchDate.leading(in: "2019-04-12T10:22:00Z") == day)
        #expect(SearchDate.leading(in: "2019-04-12 10:22") == day)
        #expect(SearchDate.leading(in: "2019-04-12x") == nil)
        #expect(SearchDate(string: "2019-13") == nil)
    }

    @Test func aPartialDateCoversItsWholeSpan() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))

        let april = try #require(SearchDate(year: 2019, month: 4)?.interval(in: calendar))
        let year = try #require(SearchDate(year: 2019)?.interval(in: calendar))

        #expect(april.duration == 30 * 86400)
        #expect(year.start <= april.start && april.end <= year.end)
    }
}
