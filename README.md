# SPFKSearch

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-search)](https://github.com/ryanfrancesconi/spfk-search/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)

A Swift package for fuzzy text search with query parsing, normalization, and configurable edit-distance scoring. Designed for matching user input against collections of searchable values — filenames, metadata tags, or any string fields.

Supports comma and space-delimited queries, automatic diacritic and case normalization, naive plural expansion, first-element weighting, and preset configurations for general search and type-ahead autocomplete.

## Making a type searchable

Conform to `Searchable` by returning an array of strings as `searchableValue`. Place the most
important field first — it receives a scoring boost — and the type gets `similarity(to:)` for free.

A `DelimitedQuery` detects its own delimiter, normalizes case and diacritics, and expands into the
terms to match: a space-delimited query keeps the full phrase alongside its individual words, a
comma-delimited one keeps only the terms, and both append singular variants for words ending in `s`.
The original string is preserved for display.

## Preset Configurations

| Config | Min Score | Description |
|--------|-----------|-------------|
| `defaultConfig` | 0.7 | General search with tight edit distance |
| `autocompleteConfig` | 0.6 | Type-ahead with prefix weighting (2.0x) and max edit distance of 1 |
| `tightEditConfig` | — | Edit-distance config with elevated gap penalties and minimal bonuses |

## Scoring

- Each query term is scored against each searchable string using edit-distance fuzzy matching
- The **first element** of `searchableValue` gets a **1.1x boost** (e.g., filename over metadata)
- **Secondary elements** get a **0.9x penalty**
- The highest score across all term/value pairs is returned
- Scores are clamped to the 0–1 range
- Returns `nil` if no score meets the minimum threshold

## Architecture

```
User Input ("haunted stonehenge moon")
    |
    v
DelimitedQuery
    |-- Detects delimiter (comma vs space)
    |-- Normalizes: case folding + diacritic removal
    |-- Splits into terms: ["haunted stonehenge moon", "haunted", "stonehenge", "moon"]
    |-- Appends singular variants for words ending in 's'
    |
    v
QuerySearch
    |-- Pairs query terms against SearchableValue [String]
    |-- Scores via FuzzyMatcher (edit-distance algorithm)
    |-- Applies first-element boost (1.1x) / secondary penalty (0.9x)
    |-- Returns best score meeting minimum threshold
    |
    v
UnitInterval (0.0 ... 1.0) or nil

Searchable Protocol
    |-- Conform any type by providing searchableValue: [String]
    |-- Gets similarity(to:) methods for free
```

## Synonym expansion

Synonym expansion is a **fallback**, and callers are responsible for treating it as one: run it only
when the literal search returned no results, and scale the resulting scores by the config's ceiling
after applying the minimum-score filter. Running it unconditionally would let an inferred match
outrank a literal one.

| Type | Description |
|------|-------------|
| **`SynonymExpander`** | Proposes additional terms — a curated tier first, then an `NLEmbedding` scan |
| **`SynonymVocabulary`** | The term set expansion is constrained to |
| **`SynonymConfig`** | Its tuning, including the score ceiling |

**Expansion is constrained to a vocabulary** rather than taking `NLEmbedding`'s free nearest
neighbors, which return the top matches across the whole embedding and can only ever suggest words
no file contains. The vocabulary is supplied by the caller — this package ships no taxonomy of its
own. TorchTag injects Vision's classification identifiers; ShadowTag's UCS terms are the same shape.
That is not merely a preference: `spfk-processing`, which owns UCS, already depends on this package,
so owning the vocabulary here would be a cycle.

A curated tier is checked before the embedding tier, because embeddings encode *relatedness*, not
synonymy — measured, `puppy` is closer to `kitten` than to `dog`. No threshold separates a synonym
from a sibling, so the cases that matter most are stated outright. The groups are symmetric and kept
deliberately small: the embedding tier covers the long tail, and every hand-written entry is a
maintenance obligation.

A lemmatizer reduces an inflected word to its dictionary form so expansion can reach terms the
inflected spelling cannot — without it, `biking` never reaches `bicycle` and lands in the activity
cluster instead. **The lemma is only used to look up candidates; it never replaces what the user
typed.** This is deliberately narrower than lemmatizing inside `DelimitedQuery`, which is shared
with ShadowTag's search and would change every search in both products rather than only the failed
ones.

## Dependencies

| Package | Purpose |
|---------|---------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | `UnitInterval`, foundation extensions, logging |
| [FuzzyMatch](https://github.com/ordo-one/FuzzyMatch) | Edit-distance scoring engine |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test utilities (test target only) |

## Requirements

- **Platforms:** macOS 14+, iOS 17+
- **Swift:** 6.2+

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
