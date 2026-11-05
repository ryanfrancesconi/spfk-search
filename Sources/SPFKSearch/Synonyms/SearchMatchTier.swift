// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

/// How a search result was reached, best first. Each tier scores within its own band and the
/// bands never overlap, so sorting by score sorts by tier.
///
/// The gaps are reserved: [0.6, 0.7) for translated terms, [0.3, 0.4) for detected labels and
/// [0.2, 0.3) for similarity. A new tier takes its gap rather than moving an existing band.
public enum SearchMatchTier: Int, Sendable, Comparable, CaseIterable {
    /// What the user typed: exact, prefix and fuzzy.
    case literal
    /// A ``CuratedSynonyms`` member of a query term.
    case curatedSynonym
    /// A vocabulary term near a query term in the word embedding.
    case embeddedSynonym

    /// Higher ranks better: `.literal > .curatedSynonym`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue > rhs.rawValue
    }

    /// The scores this tier can produce.
    public var band: ClosedRange<UnitInterval> {
        switch self {
        case .literal: QuerySearch.defaultConfig.minScore ... 1
        case .curatedSynonym: 0.5 ... UnitInterval(0.6).nextDown
        case .embeddedSynonym: 0.4 ... UnitInterval(0.5).nextDown
        }
    }

    /// `quality` placed within ``band``. A literal score is the scorer's own and passes through.
    public func score(quality: UnitInterval) -> UnitInterval {
        guard self != .literal else { return quality }

        let band = band
        let width = band.upperBound.nextUp - band.lowerBound
        let q = min(max(quality, 0), 1)

        return min(band.lowerBound + q * width, band.upperBound)
    }

    /// The quality of a scorer result in `0...1`, for ``score(quality:)``.
    public static func quality(ofLiteralScore score: UnitInterval) -> UnitInterval {
        let floor = QuerySearch.defaultConfig.minScore
        return min(max((score - floor) / (1 - floor), 0), 1)
    }
}
