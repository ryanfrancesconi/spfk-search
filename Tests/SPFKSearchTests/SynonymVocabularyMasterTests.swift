// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SoundAnalysis
import SPFKBase
import SPFKTesting
import Testing
import Vision

@testable import SPFKSearch

@Suite(.tags(.synonyms))
struct SynonymVocabularyMasterTests {
    private var masterForms: Set<String> {
        Set(SynonymVocabulary.master.terms.map { $0.matchForm.lowercased() })
    }

    private func spaced(_ identifier: String) -> String {
        identifier.snakeCaseWords.joined(separator: " ").lowercased()
    }

    @Test func masterHoldsEveryVisionLabel() throws {
        let identifiers = try VNClassifyImageRequest().supportedIdentifiers()
        let forms = masterForms

        #expect(identifiers.isNotEmpty)
        #expect(identifiers.filter { !forms.contains(spaced($0)) } == [])
    }

    @Test func masterHoldsEverySoundLabel() throws {
        let identifiers = try SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications
        let forms = masterForms

        #expect(identifiers.isNotEmpty)
        #expect(identifiers.filter { !forms.contains(spaced($0)) } == [])
    }

    @Test func masterHasNoDuplicateMatchForm() {
        let forms = SynonymVocabulary.master.terms.map { $0.matchForm.lowercased() }

        #expect(forms.count == Set(forms).count)
    }

    @Test func addingKeepsEveryTermOnce() {
        let base = SynonymVocabulary(identifiers: ["bicycle", "dog"])
        let other = SynonymVocabulary(identifiers: ["riser", "dog", "whoosh"])

        let forms = base.adding(other).terms.map(\.matchForm)

        #expect(forms == ["bicycle", "dog", "riser", "whoosh"])
    }

    /// The match form a search emits is the receiver's spelling, and its vector comes along.
    @Test func addingKeepsTheReceiversTermOnAClash() throws {
        let base = SynonymVocabulary(identifiers: ["Dog"])
        let other = SynonymVocabulary(identifiers: ["dog"])

        let merged = base.adding(other)
        let term = try #require(merged.terms.first)

        #expect(merged.terms.count == 1)
        #expect(term.matchForm == "Dog")
        #expect(term.vector == base.terms.first?.vector)
    }

    @Test func identifiersEmbedEachMatchFormOnce() {
        let forms = SynonymVocabulary(identifiers: ["dog_bark", "Dog Bark", "dog", "dog"]).terms.map(\.matchForm)

        #expect(forms == ["dog bark", "dog"])
    }

    @Test func addingIdentifiersSkipsHeldFormsAndKeepsTheReceiversSpelling() {
        let base = SynonymVocabulary(identifiers: ["dog", "bicycle"])
        let forms = base.adding(identifiers: ["DOG", "Riser", "riser", "Bicycle"]).terms.map(\.matchForm)

        #expect(forms == ["dog", "bicycle", "Riser"])
    }
}
