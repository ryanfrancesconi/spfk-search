// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import Testing

@testable import SPFKSearch

@Suite
final class TextReplacerTests {
    private func replacer(
        _ find: String,
        _ replacement: String = "",
        matchCase: Bool = false,
        wholeWord: Bool = false,
        ignoreDiacritics: Bool = false,
        useRegex: Bool = false
    ) throws -> TextReplacer {
        try TextReplacer(
            find: find,
            replacement: replacement,
            options: TextMatchOptions(
                matchCase: matchCase,
                wholeWord: wholeWord,
                ignoreDiacritics: ignoreDiacritics,
                useRegex: useRegex
            )
        )
    }

    // MARK: - Case

    @Test func caseInsensitiveMatchesEveryCasingAndPreservesSurroundingText() throws {
        let subject = try replacer("kick", "snare")

        #expect(subject.replacing("Kick")?.result == "snare")
        #expect(subject.replacing("KICK")?.result == "snare")
        #expect(subject.replacing("A KICK and a Kick in kick_01")?.result == "A snare and a snare in snare_01")
    }

    @Test func matchCaseRestrictsToTheExactCasing() throws {
        let subject = try replacer("Kick", "snare", matchCase: true)

        #expect(subject.replacing("Kick KICK kick")?.result == "snare KICK kick")
        #expect(subject.replacing("KICK") == nil)
    }

    // MARK: - Diacritics, width and quotes

    @Test func ignoreDiacriticsMatchesAccentedTextAndSplicesTheFoundRange() throws {
        let subject = try replacer("cafe", "bar", ignoreDiacritics: true)

        #expect(subject.replacing("Café au lait")?.result == "bar au lait")
        #expect(try replacer("cafe", "bar").replacing("Café au lait") == nil)
    }

    @Test func ignoreDiacriticsSplicesTheWholeDecomposedSequence() throws {
        let decomposed = "Cafe\u{0301} au lait"
        let subject = try replacer("café", "bar", ignoreDiacritics: true)

        let result = try #require(subject.replacing(decomposed))

        #expect(result.result == "bar au lait")
        #expect(result.result.unicodeScalars.contains("\u{0301}") == false)
    }

    @Test func ignoreDiacriticsFoldsWidthButNotKanaVoicing() throws {
        #expect(try replacer("ABC", "x", ignoreDiacritics: true).replacing("ＡＢＣ")?.result == "x")
        #expect(try replacer("ドラム", "x", ignoreDiacritics: true).replacing("ﾄﾞﾗﾑ")?.result == "x")
        #expect(try replacer("か", "x", ignoreDiacritics: true).replacing("が") == nil)
    }

    @Test func ignoreDiacriticsFoldsApostropheAndQuoteStyle() throws {
        let apostrophe = try replacer("l'homme", "l'ami", ignoreDiacritics: true)
        #expect(apostrophe.replacing("l\u{2019}homme")?.result == "l'ami")

        let quote = try replacer("\"drum\"", "drum", ignoreDiacritics: true)
        #expect(quote.replacing("a \u{201C}drum\u{201D} hit")?.result == "a drum hit")
    }

    @Test func quoteFoldingIsOffWithoutIgnoreDiacritics() throws {
        #expect(try replacer("l'homme", "x").replacing("l\u{2019}homme") == nil)
        #expect(try replacer("\"drum\"", "x").replacing("\u{201C}drum\u{201D}") == nil)
    }

    @Test func quoteFoldingReplacesOnlyTheMatchAndLeavesOtherQuotesAlone() throws {
        let subject = try replacer("old", "new", ignoreDiacritics: true)
        let text = "it\u{2019}s the old one"

        #expect(subject.replacing(text)?.result == "it\u{2019}s the new one")
    }

    // MARK: - Whole word

    @Test func wholeWordRejectsAPartialWordAndAcceptsAPunctuationBoundary() throws {
        let subject = try replacer("drum", "kit", wholeWord: true)

        #expect(subject.replacing("drums") == nil)
        #expect(subject.replacing("drum, snare")?.result == "kit, snare")
        #expect(subject.replacing("kick_drum") == nil)
    }

    @Test func wholeWordUsesICUBreaksForCJK() throws {
        #expect(try replacer("小鼓", "x", wholeWord: true).replacing("大鼓和小鼓")?.result == "大鼓和x")
        #expect(try replacer("鼓", "x", wholeWord: true).replacing("大鼓和小鼓") == nil)
    }

    @Test func wholeWordUsesTheAlphanumericRuleForElision() throws {
        #expect(try replacer("homme", "femme", wholeWord: true).replacing("l'homme")?.result == "l'femme")
    }

    @Test func wholeWordAppliesTheSamePredicateInRegexMode() throws {
        #expect(try replacer("小鼓", "x", wholeWord: true, useRegex: true).replacing("大鼓和小鼓")?.result == "大鼓和x")
        #expect(try replacer("鼓", "x", wholeWord: true, useRegex: true).replacing("大鼓和小鼓") == nil)
        #expect(try replacer("homme", "femme", wholeWord: true, useRegex: true).replacing("l'homme")?.result == "l'femme")
        #expect(try replacer("drum", "kit", wholeWord: true, useRegex: true).replacing("drums") == nil)
    }

    // MARK: - Regex

    @Test func regexExpandsCaptureGroupsInTheTemplate() throws {
        let subject = try replacer("(\\d+)", "[$1]", useRegex: true)

        #expect(subject.replacing("take 12 and take 3")?.result == "take [12] and take [3]")
    }

    @Test func regexIsCaseInsensitiveUnlessMatchCaseIsOn() throws {
        #expect(try replacer("kick", "x", useRegex: true).replacing("KICK")?.result == "x")
        #expect(try replacer("kick", "x", matchCase: true, useRegex: true).replacing("KICK") == nil)
    }

    @Test func invalidPatternThrowsWithAMessage() throws {
        #expect(throws: TextReplacerError.self) {
            try self.replacer("(unclosed", "x", useRegex: true)
        }

        do {
            _ = try replacer("(unclosed", "x", useRegex: true)
            Issue.record("expected a throw")
        } catch let error as TextReplacerError {
            guard case let .invalidPattern(message) = error else {
                Issue.record("expected .invalidPattern")
                return
            }
            #expect(message.isEmpty == false)
        }
    }

    // MARK: - Degenerate input

    @Test func emptyFindThrows() {
        #expect(throws: TextReplacerError.emptyFind) {
            _ = try TextReplacer(find: "", replacement: "x", options: TextMatchOptions())
        }
    }

    @Test func emptyReplacementDeletesTheMatch() throws {
        #expect(try replacer("old ", "").replacing("old kit")?.result == "kit")
    }

    @Test func noMatchReturnsNil() throws {
        #expect(try replacer("kick", "snare").replacing("hi hat") == nil)
        #expect(try replacer("kick", "snare").replacing("") == nil)
        #expect(try replacer("kick", "snare").matchCount(in: "hi hat") == 0)
    }

    @Test func countIsTheNumberOfNonOverlappingMatches() throws {
        let subject = try replacer("aa", "b")

        #expect(subject.matchCount(in: "aaaa") == 2)
        #expect(subject.replacing("aaaa")?.count == 2)
        #expect(subject.replacing("aaaaa")?.result == "bba")
        #expect(subject.matchCount(in: "kick kick kick") == 0)
    }
}
