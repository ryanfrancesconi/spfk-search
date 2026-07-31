// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

/// Tuning for ``SynonymExpander``.
///
/// Synonym expansion is a *fallback*: it runs only when a literal search returned no results at
/// all. Nothing here affects a search that found something.
public struct SynonymConfig: Sendable {
    /// Maximum distance for a vocabulary term to be accepted as an expansion of a query term.
    ///
    /// **This is on the cosine-distance scale computed over averaged word vectors, not the scale
    /// `NLEmbedding.distance(between:and:)` returns.** The two differ substantially for the same
    /// pair — `bike`/`bicycle` is 0.216 here and 0.657 through that API — because expansion has
    /// to support multi-word terms, which `distance(between:and:)` cannot score at all
    /// (`NLEmbedding` has no vector for a compound). Comparing a threshold from one scale against
    /// the other silently accepts or rejects everything.
    ///
    /// Measured pairs on this scale:
    ///
    /// ```
    /// bike/bicycle    0.216  synonym
    /// boat/sailboat   0.242  synonym
    /// sunset/sunrise  0.278  sibling
    /// puppy/kitten    0.293  sibling
    /// puppy/dog       0.312  sibling
    /// bike/dog        0.709  unrelated
    /// ```
    ///
    /// The break falls between 0.242 and 0.278, hence the 0.25 default. Err tight: too strict
    /// means a term does not expand and the user sees the same empty result they see today,
    /// while too loose means unrelated files presented as related.
    public var maximumDistance: Double

    /// Maximum expansion terms contributed by any single query term, best (closest) first.
    public var maximumExpansionsPerTerm: Int

    /// Multiplier applied to every score produced by an expanded pass, so a synonym match can
    /// never score as high as a literal one.
    ///
    /// The justification is provenance rather than semantic distance: `bike` and `bicycle` mean
    /// the same thing, but `bicycle` is still not the word the user typed — the app inferred it
    /// on their behalf. So this applies to curated and embedding-derived terms alike.
    ///
    /// Callers must apply it *after* their minimum-score filter. Scaling before the filter turns
    /// it into a stricter threshold that discards marginal matches instead of demoting them.
    public var scoreCeiling: UnitInterval

    /// Whether the curated table tier runs.
    public var usesCuratedTable: Bool

    /// Whether the `NLEmbedding` tier runs. Has no effect when no word embedding is available.
    public var usesEmbedding: Bool

    public static let `default` = SynonymConfig()

    public init(
        maximumDistance: Double = 0.25,
        maximumExpansionsPerTerm: Int = 5,
        scoreCeiling: UnitInterval = 0.8,
        usesCuratedTable: Bool = true,
        usesEmbedding: Bool = true
    ) {
        self.maximumDistance = maximumDistance
        self.maximumExpansionsPerTerm = maximumExpansionsPerTerm
        self.scoreCeiling = scoreCeiling
        self.usesCuratedTable = usesCuratedTable
        self.usesEmbedding = usesEmbedding
    }
}
