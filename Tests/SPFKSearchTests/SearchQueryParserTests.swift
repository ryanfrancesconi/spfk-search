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

    // MARK: - Operand limits

    @Test func aRelativeAmountTooLargeForAnIntIsInvalid() {
        for amount in ["99999999999999999999", String(repeating: "9", count: 400)] {
            let text = "date in last \(amount)d"
            let result = parse(text)
            #expect(result.criteria == .text(text))
            #expect(result.diagnostics.map(\.kind) == [.invalidValue])
        }
    }

    @Test func aNonFiniteNumberIsInvalid() {
        let nines = String(repeating: "9", count: 400)

        for text in ["bpm > \(nines)", "bpm == 1..\(nines)", "size > 1\(String(repeating: "0", count: 300))GB"] {
            let result = parse(text)
            #expect(result.criteria == .text(text))
            #expect(result.diagnostics.map(\.kind) == [.invalidValue])
        }
    }

    @Test(arguments: [
        ("6mo", SearchOperand.relative(amount: 6, unit: .month)),
        ("2weeks", .relative(amount: 2, unit: .week)),
        ("1y", .relative(amount: 1, unit: .year)),
    ])
    func relativeAmountsReadTheirUnit(value: String, expected: SearchOperand) {
        #expect(criteria("date in last \(value)") == rule("tag.date", .inTheLast, expected))
    }

    @Test(arguments: ["0d", "-3d", "1.5d", "3x"])
    func aRelativeAmountMustBeAPositiveWholeNumberOfAUnit(value: String) {
        let text = "date in last \(value)"
        let result = parse(text)
        #expect(result.criteria == .text(text))
        #expect(result.diagnostics.map(\.kind) == [.invalidValue])
    }

    @Test func unitSuffixesScaleToTheFieldsBaseUnit() {
        #expect(criteria("duration < 1h") == rule("format.duration", .lessThan, .number(3600)))
        #expect(criteria("size > 1.5GB") == rule("file.size", .greaterThan, .number(1_500_000_000)))
        #expect(criteria("size > 2KB") == rule("file.size", .greaterThan, .number(2000)))
        #expect(criteria("\"sample rate\" == 48khz") == rule("format.sampleRate", .is, .number(48000)))

        let result = parse("bpm > 10k")
        #expect(result.criteria == .text("bpm > 10k"))
        #expect(result.diagnostics.map(\.kind) == [.invalidValue])
    }

    @Test func aListOnAFieldWithoutOptionsIsAnInvalidOperator() {
        let result = parse("genre in (a, b)")
        #expect(result.criteria == .text("genre in (a, b)"))
        #expect(result.diagnostics.map(\.kind) == [.invalidOperator])
    }

    @Test func anEmptyListIsAnInvalidValue() {
        let result = parse("type in ()")
        #expect(result.criteria == .text("type in ()"))
        #expect(result.diagnostics.map(\.kind) == [.invalidValue])
    }

    // MARK: - Negation edges

    @Test func aDashBeforeAClosingParenthesisIsText() {
        let result = parse("(rain -)")
        #expect(result.criteria == .group(.all, [.text("rain"), .text("-")]))
        #expect(result.diagnostics.isEmpty)
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
            rule("playlist", .isIn, .playlists([UUID(), UUID()])),
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

    @Test func aPlaylistRuleIsPinnedAndReadsItsUUIDs() throws {
        let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000A1"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-0000000000B2"))
        let json = #"{"field":"playlist","operand":{"type":"playlists","value":["\#(first.uuidString)","\#(second.uuidString)"]},"operator":"isNotIn","type":"rule"}"#

        let decoded = try JSONDecoder().decode(SearchCriteria.self, from: Data(json.utf8))

        #expect(decoded == rule("playlist", .isNotIn, .playlists([first, second])))
        #expect(String(decoding: try Self.encoder.encode(decoded), as: UTF8.self) == json)
        #expect(decoded.referencedPlaylistIDs == [first, second])
    }

    @Test func aPlaylistOperandWithABadUUIDIsAnUnknownNode() throws {
        let json = #"{"field":"playlist","operand":{"type":"playlists","value":["not a uuid"]},"operator":"isIn","type":"rule"}"#

        let decoded = try JSONDecoder().decode(SearchCriteria.self, from: Data(json.utf8))

        guard case .unknown = decoded else {
            Issue.record("expected an unknown node, got \(decoded)")
            return
        }
        #expect(decoded.referencedPlaylistIDs.isEmpty)
    }

    @Test func referencedPlaylistsAreCollectedAtAnyDepth() {
        let first = UUID()
        let second = UUID()

        let criteria = SearchCriteria.group(.all, [
            rule("playlist", .isIn, .playlists([first])),
            .group(.none, [rule("playlist", .isNotIn, .playlists([first, second])), .text("rain")]),
            rule("tag.bpm", .is, .number(120)),
        ])

        #expect(criteria.referencedPlaylistIDs == [first, second])
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
