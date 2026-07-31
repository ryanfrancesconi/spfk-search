// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import NaturalLanguage

/// Reduces an inflected word to its dictionary form, so expansion can reach terms the inflected
/// spelling cannot.
///
/// Without this, `"biking"` never reaches `"bicycle"` — measured, it lands in the activity cluster
/// (`hiking`, `rafting`, `trail`) instead.
///
/// **The lemma is only used to look up expansion candidates; it never replaces the term the user
/// typed.** A search for `"biking"` still matches `"biking"` literally, and additionally expands
/// via `"bike"`. This is deliberately narrower than lemmatizing inside `DelimitedQuery`: that type
/// is shared with ShadowTag's search, so changing it would alter every search in both products
/// rather than only the failed ones this feature runs on.
enum Lemmatizer {
    /// The dictionary form of `word`, or `nil` when there is no distinct lemma.
    ///
    /// Returns `nil` rather than the input when the lemma matches the word, so callers can skip
    /// redundant lookups.
    static func lemma(for word: String) -> String? {
        guard word.isNotEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = word

        guard let tag = tagger.tag(at: word.startIndex, unit: .word, scheme: .lemma).0 else {
            return nil
        }

        let lemma = tag.rawValue.lowercased()

        guard lemma.isNotEmpty, lemma != word.lowercased() else { return nil }

        return lemma
    }
}
