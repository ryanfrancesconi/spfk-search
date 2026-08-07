// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase

extension QuerySearch {
    /// Scores all entries against `query` with a single shared ``FuzzyMatcher`` and ``ScoringBuffer``.
    ///
    /// Matcher, buffer and query-term preparation happen once for the batch rather than per
    /// element.
    ///
    /// - Parameters:
    ///   - candidates: The searchable items to score.
    ///   - query: The parsed search query.
    ///   - matchConfig: Matching configuration.
    /// - Returns: `(element, score)` pairs whose score exceeds `matchConfig.minScore`,
    ///   in the same relative order as `candidates`.
    public static func batchScore<T: Searchable>(
        _ candidates: [T],
        query: DelimitedQuery,
        matchConfig: MatchConfig
    ) -> [(element: T, score: UnitInterval)] {
        guard !candidates.isEmpty, !query.array.isEmpty else { return [] }

        let matcher = FuzzyMatcher(config: matchConfig)
        var buffer = matcher.makeBuffer()
        let preparedTerms = query.array.map { matcher.prepare($0) }

        var results: [(element: T, score: UnitInterval)] = []
        for candidate in candidates {
            let score = Self.scoreCandidate(
                searchableValue: candidate.searchableValue,
                preparedTerms: preparedTerms,
                matcher: matcher,
                buffer: &buffer,
                minScore: matchConfig.minScore
            )
            if score > 0 {
                results.append((candidate, score))
            }
        }
        return results
    }

    /// Scores all entries against `query` in parallel using ``withTaskGroup``.
    ///
    /// One chunk per core, each with its own ``ScoringBuffer``; the matcher and prepared terms are
    /// shared.
    ///
    /// - Parameters:
    ///   - candidates: The searchable items to score.
    ///   - query: The parsed search query.
    ///   - matchConfig: Matching configuration.
    ///   - earlyExitScore: Cancel remaining chunks as soon as any result reaches this score.
    ///     Defaults to `1.0` (only exit on a perfect match). Pass a lower value (e.g. `0.95`)
    ///     to exit sooner when a near-perfect result is sufficient.
    /// - Returns: `(element, score)` pairs whose score exceeds `matchConfig.minScore`.
    ///   Order is non-deterministic across chunks.
    public static func parallelBatchScore<T: Searchable>(
        _ candidates: [T],
        query: DelimitedQuery,
        matchConfig: MatchConfig,
        earlyExitScore: UnitInterval = 1.0
    ) async -> [(element: T, score: UnitInterval)] {
        guard !candidates.isEmpty, !query.array.isEmpty else { return [] }

        let matcher = FuzzyMatcher(config: matchConfig)
        let preparedTerms = query.array.map { matcher.prepare($0) }
        let minScore = matchConfig.minScore

        let cpuCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let chunkSize = max(1, (candidates.count + cpuCount - 1) / cpuCount)

        return await withTaskGroup(of: [(T, UnitInterval)].self) { group in
            var offset = 0
            while offset < candidates.count {
                let end = min(offset + chunkSize, candidates.count)
                let chunk = Array(candidates[offset ..< end])
                offset += chunkSize

                group.addTask {
                    var buffer = matcher.makeBuffer()
                    var partial: [(T, UnitInterval)] = []
                    for candidate in chunk {
                        let score = scoreCandidate(
                            searchableValue: candidate.searchableValue,
                            preparedTerms: preparedTerms,
                            matcher: matcher,
                            buffer: &buffer,
                            minScore: minScore
                        )
                        if score > 0 {
                            partial.append((candidate, score))
                        }
                    }
                    return partial
                }
            }

            var results: [(T, UnitInterval)] = []
            for await partial in group {
                results.append(contentsOf: partial)
                // Cancel remaining chunks once a result meets the early-exit threshold.
                // withTaskGroup automatically cancels and drains remaining tasks on break.
                if partial.contains(where: { $0.1 >= earlyExitScore }) {
                    group.cancelAll()
                    break
                }
            }
            return results
        }
    }

    // MARK: - Internal

    /// Scores a single candidate's searchable fields against pre-prepared query terms.
    ///
    /// Returns the highest score across all (term × field) pairs that meets `minScore`,
    /// or `0` if no pair does. Early-exits as soon as a perfect score (1.0) is found.
    ///
    /// The first searchable element (j==0, typically the primary category name) receives a
    /// 1.1× boost when the query term is a semantically exact match (`ScoredMatch.kind == .exact`),
    /// or a 0.9× penalty otherwise. This prevents short prefix matches (e.g. "bird"→"BIRDS",
    /// "metro"→"METAL") from amplifying to 1.0 and outranking exact synonym matches.
    internal static func scoreCandidate(
        searchableValue: SearchableValue,
        preparedTerms: [FuzzyQuery],
        matcher: FuzzyMatcher,
        buffer: inout ScoringBuffer,
        minScore: UnitInterval
    ) -> UnitInterval {
        var topScore: UnitInterval = 0
        let searchableCount = searchableValue.count
        var done = false

        for fuzzyQuery in preparedTerms {
            if done { break }
            for j in 0 ..< searchableCount {
                guard let wordScore = matcher.score(searchableValue[j], against: fuzzyQuery, buffer: &buffer) else { continue }

                var score = wordScore.score
                if searchableCount > 1 {
                    if j == 0 {
                        // Boost only on a semantically exact match (same length, every
                        // char matches). Prefix/fuzzy matches get the 0.9× synonym
                        // penalty — this prevents short terms like "bird"→"BIRDS" or
                        // "metro"→"METAL" from amplifying to 1.0 via the j==0 boost
                        // and drowning out exact synonym matches in j>0 fields.
                        score *= wordScore.kind == .exact ? 1.1 : 0.9
                    } else {
                        score *= 0.9
                    }
                    score = min(score, 1.0)
                }

                guard score >= minScore else { continue }

                if score > topScore {
                    topScore = score
                    if topScore >= 1.0 { done = true; break }
                }
            }
        }

        return topScore
    }

    /// Computes the fuzzy similarity score between ``query`` and ``searchableValue``.
    ///
    /// Iterates all query terms against all searchable strings using `FuzzyMatcher`.
    /// The first searchable element receives a 1.1x boost; subsequent elements
    /// receive a 0.9x penalty. Returns the highest score that meets ``minimumScore``,
    /// clamped to 0–1.
    ///
    /// Called automatically during ``QuerySearch/init(searchableValue:query:matchConfig:)``;
    /// the result is stored in ``similarity``.
    ///
    /// - Returns: The best match score (0–1), or `0` if no term meets the threshold.
    public func fuzzySimilarity() -> UnitInterval {
        var topScore: UnitInterval = 0

        let matcher = FuzzyMatcher(config: matchConfig)
        var buffer = matcher.makeBuffer()

        let queryCount = query.array.count
        let searchableCount = searchableValue.count

        for i in 0 ..< queryCount {
            let word = query.array[i]

            let fuzzyQuery = matcher.prepare(word)

            for j in 0 ..< searchableCount {
                let value = searchableValue[j]

                guard let wordScore = matcher.score(value, against: fuzzyQuery, buffer: &buffer) else { continue }

                var score = wordScore.score

                // give extra weight if is the first element, generally filename
                if searchableCount > 1 {
                    score *= (j == 0 ? 1.1 : 0.9)
                    score = min(score, 1.0)
                }

                guard score >= matchConfig.minScore else { continue }

                #if DEBUG
                // Log.debug("'\(word)' matching '\(value)' = \(wordScore), \(matchConfig.minScore)")
                #endif

                if score > topScore {
                    topScore = score
                    if topScore >= 1.0 { return 1.0 }
                }
            }
        }

        return topScore.clamped(to: 0 ... 1)
    }
}
