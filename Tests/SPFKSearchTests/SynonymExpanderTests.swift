// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class SynonymExpanderTests: TestCaseModel {
    /// A Vision-shaped vocabulary: lowercase identifiers, some snake_case compounds.
    static let identifiers = [
        "bicycle", "cycling", "motorcycle", "tricycle",
        "dog", "cat", "kitten", "puppy",
        "toaster_oven", "train_station", "parking_lot",
        "automobile", "sailboat", "sunset", "sunrise",
        "flower", "television", "telephone",
    ]

    private func makeExpander(config: SynonymConfig = .default) -> SynonymExpander {
        SynonymExpander(
            vocabulary: SynonymVocabulary(identifiers: Self.identifiers),
            config: config
        )
    }

    // MARK: - The reported case

    @Test func bikeExpandsToBicycle() throws {
        let expansions = makeExpander().expansions(for: ["bike"])

        #expect(expansions.contains("bicycle"))
    }

    @Test func expansionsExcludeTermsTheUserTyped() throws {
        let expansions = makeExpander().expansions(for: ["bike", "bicycle"])

        #expect(!expansions.contains("bicycle"))
    }

    // MARK: - Vocabulary constraint

    @Test func expansionsNeverLeaveTheVocabulary() throws {
        let vocabulary = Set(Self.identifiers.map { $0.snakeCaseToTitle.lowercased() })
        let expander = makeExpander()

        for term in ["bike", "car", "boat", "puppy", "phone", "photo", "sunset"] {
            for expansion in expander.expansions(for: [term]) {
                #expect(
                    vocabulary.contains(expansion.lowercased()),
                    "'\(expansion)' from '\(term)' is not a vocabulary term"
                )
            }
        }
    }

    @Test func emptyVocabularyProducesNoExpansions() throws {
        let expander = SynonymExpander(vocabulary: SynonymVocabulary(identifiers: []))

        #expect(expander.expansions(for: ["bike"]).isEmpty)
    }

    // MARK: - Compound terms

    /// `NLEmbedding` has no vector for a multi-word string, so a compound identifier only
    /// participates in the embedding tier if its component words are embedded and averaged.
    /// Without that, ~15% of Vision's vocabulary drops out silently.
    @Test func compoundIdentifiersAreEmbedded() throws {
        let vocabulary = SynonymVocabulary(identifiers: ["toaster_oven"])
        let term = try #require(vocabulary.terms.first)

        #expect(term.matchForm == "toaster oven")
        #expect(term.words == ["toaster", "oven"])
        #expect(term.vector != nil)
        #expect(term.norm > 0)
    }

    @Test func unembeddableIdentifiersSurviveWithoutAVector() throws {
        let vocabulary = SynonymVocabulary(identifiers: ["xq7_zzplex"])
        let term = try #require(vocabulary.terms.first)

        #expect(term.matchForm == "xq7 zzplex")
        #expect(term.vector == nil)
    }

    // MARK: - Threshold

    /// Distances for unrelated terms measured far above the default threshold, so a query with
    /// no semantic neighbors in the vocabulary must expand to nothing rather than to its least
    /// bad match.
    @Test func unrelatedTermsExpandToNothing() throws {
        let expansions = makeExpander().expansions(for: ["asphalt"])

        #expect(expansions.isEmpty)
    }

    @Test func loosenedThresholdAdmitsMoreTerms() throws {
        let tight = makeExpander(config: SynonymConfig(maximumDistance: 0.05))
        let loose = makeExpander(config: SynonymConfig(maximumDistance: 0.9))

        #expect(tight.expansions(for: ["puppy"]).count < loose.expansions(for: ["puppy"]).count)
    }

    @Test func expansionsPerTermAreCapped() throws {
        let expander = makeExpander(
            config: SynonymConfig(maximumDistance: 0.9, maximumExpansionsPerTerm: 2)
        )

        #expect(expander.expansions(for: ["puppy"]).count <= 2)
    }

    // MARK: - Tiers

    @Test func curatedHitSuppressesTheEmbeddingTier() throws {
        // "bike"/"bicycle" is curated. With the embedding tier disabled the expansion must still
        // appear, proving it came from the curated table rather than from embedding proximity.
        let curatedOnly = makeExpander(
            config: SynonymConfig(usesCuratedTable: true, usesEmbedding: false)
        )

        #expect(curatedOnly.expansions(for: ["bike"]) == ["bicycle"])
    }

    @Test func embeddingTierRunsWhenNothingIsCurated() throws {
        let embeddingOnly = makeExpander(
            config: SynonymConfig(usesCuratedTable: false, usesEmbedding: true)
        )

        // "boat" is in no curated group, but "sailboat" is a close vocabulary neighbor.
        #expect(embeddingOnly.expansions(for: ["boat"]).contains("sailboat"))
    }

    @Test func bothTiersDisabledProducesNothing() throws {
        let disabled = makeExpander(
            config: SynonymConfig(usesCuratedTable: false, usesEmbedding: false)
        )

        #expect(disabled.expansions(for: ["bike"]).isEmpty)
    }

    // MARK: - Lemmatization

    /// The lemma is a lookup key only. An inflected term has its own (wrong) vector — "biking"
    /// clusters with hiking/rafting — so the lemma must be searched alongside it, not merely as
    /// a fallback for a missing vector.
    ///
    /// Runs with the embedding tier disabled so this can only pass via the lemma reaching the
    /// curated `bike`/`bicycle` group — otherwise embedding proximity to `cycling`/`bicycle`
    /// would make it pass for the wrong reason.
    @Test func inflectedTermsReachTheirLemmasSynonyms() throws {
        let curatedOnly = makeExpander(
            config: SynonymConfig(usesCuratedTable: true, usesEmbedding: false)
        )

        #expect(curatedOnly.expansions(for: ["biking"]) == ["bicycle"])
    }

    /// `NLTagger`'s lemma coverage is real but **partial and not predictable per word** — measured
    /// in this target, `cars`/`flowers`/`children`/`boxes` resolve while `dogs`/`mice`/`sunsets`
    /// return nil, with no rule separating them. That is tolerable because it is additive:
    /// `DelimitedQuery` already contributes trailing-s singulars, and the original term is always
    /// searched regardless. So this asserts the contract, not a word list.
    @Test func lemmaReducesInflectedForms() throws {
        #expect(Lemmatizer.lemma(for: "biking") == "bike")
        #expect(Lemmatizer.lemma(for: "running") == "run")
    }

    @Test func lemmaIsNilWhenThereIsNoDistinctLemma() throws {
        #expect(Lemmatizer.lemma(for: "bike") == nil)
        #expect(Lemmatizer.lemma(for: "") == nil)
    }

    // MARK: - Short terms

    /// The length gate applies to the embedding tier only. A short curated entry is deliberate,
    /// and `"tv"` is exactly the kind of query the curated table exists to serve — gating it out
    /// would discard a known-good answer to avoid noise that cannot occur.
    @Test func shortTermsStillUseTheCuratedTier() throws {
        #expect(makeExpander().expansions(for: ["tv"]) == ["television"])
    }

    @Test func shortTermsAreNotSentToTheEmbeddingTier() throws {
        let embeddingOnly = makeExpander(
            config: SynonymConfig(usesCuratedTable: false, usesEmbedding: true)
        )

        #expect(embeddingOnly.expansions(for: ["tv"]).isEmpty)
    }

    // MARK: - Dedupe

    @Test func repeatedExpansionsAppearOnce() throws {
        // Both spellings are curated to "bicycle"; it must not be contributed twice.
        let expansions = makeExpander().expansions(for: ["bike", "biking"])

        #expect(expansions.filter { $0 == "bicycle" }.count == 1)
    }
}
