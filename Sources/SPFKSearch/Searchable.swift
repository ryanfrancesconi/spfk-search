// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

/// An array of strings representing the searchable fields of a type.
///
/// The first element is given a slight scoring boost (1.1x) to prioritize
/// primary fields such as filename over secondary metadata like artist or album.
public typealias SearchableValue = [String]

/// A type whose instances can be searched by fuzzy text matching.
///
/// Conform to `Searchable` by returning an array of strings from
/// ``searchableValue``. The protocol extension provides ``similarity(to:minimumScore:)``
/// and ``similarity(to:matchConfig:)`` for free.
///
/// ```swift
/// struct AudioFile: Searchable {
///     let filename: String
///     let artist: String
///     var searchableValue: SearchableValue { [filename, artist] }
/// }
///
/// let score = audioFile.similarity(to: DelimitedQuery(string: "piano"))
/// ```
public protocol Searchable: Sendable, Hashable {
    /// The strings to match against when searching this instance.
    ///
    /// Place the most important field first — it receives a scoring boost.
    var searchableValue: SearchableValue { get }
}

extension Searchable {
    /// Returns the fuzzy similarity score between this instance and the query,
    /// or `nil` if no term meets the minimum score threshold.
    ///
    /// - Parameters:
    ///   - query: The parsed search query.
    ///   - minimumScore: The minimum similarity score (0–1) required to return a result.
    /// - Returns: The best match score, or `nil` if below the threshold.
    public func similarity(
        to query: DelimitedQuery,
        minimumScore: UnitInterval
    ) -> UnitInterval? {
        let querySearch = QuerySearch(
            searchableValue: searchableValue,
            query: query,
            minimumScore: minimumScore
        )

        return querySearch.similarity
    }

    /// Returns the fuzzy similarity score between this instance and the query,
    /// or `nil` if no term meets the config's minimum score.
    ///
    /// - Parameters:
    ///   - query: The parsed search query.
    ///   - matchConfig: Matching configuration. Defaults to ``QuerySearch/defaultConfig``.
    /// - Returns: The best match score, or `nil` if below the threshold.
    public func similarity(
        to query: DelimitedQuery,
        matchConfig: MatchConfig? = nil

    ) -> UnitInterval? {
        let querySearch = QuerySearch(
            searchableValue: searchableValue,
            query: query,
            matchConfig: matchConfig
        )

        return querySearch.similarity
    }
}
