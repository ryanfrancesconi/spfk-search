// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// Hand-authored synonym groups, checked before the embedding tier.
///
/// These exist because word embeddings encode *relatedness*, not synonymy — measured,
/// `puppy` is closer to `kitten` (0.293) than to `dog` (0.312). No threshold separates a synonym
/// from a sibling, so the cases that matter most are stated outright instead.
///
/// Groups are symmetric: any member expands to all the others. Kept deliberately small — the
/// embedding tier covers the long tail, and every entry here is a maintenance obligation. Only
/// add true synonyms; a sibling pair (`sunset`/`sunrise`, `dog`/`cat`) belongs in neither tier.
enum CuratedSynonyms {
    static let groups: [[String]] = [
        ["bike", "bicycle"],
        ["car", "automobile", "auto"],
        ["photo", "photograph", "picture", "pic"],
        ["plane", "airplane", "aircraft"],
        ["dog", "canine"],
        ["cat", "feline"],
        ["kid", "child"],
        ["couch", "sofa"],
        ["tv", "television"],
        ["phone", "telephone"],
        ["railroad", "railway"],
        ["store", "shop"],
        ["flower", "blossom"],
    ]

    /// Maps each member to the other members of its group.
    private static let index: [String: [String]] = {
        var result: [String: [String]] = [:]

        for group in groups {
            for member in group {
                result[member, default: []] += group.filter { $0 != member }
            }
        }
        return result
    }()

    /// The curated synonyms of `term`, or an empty array when it is not in any group.
    static func synonyms(for term: String) -> [String] {
        index[term.lowercased()] ?? []
    }
}
