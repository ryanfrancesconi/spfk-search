# SPFKSearch

[![CI](https://github.com/ryanfrancesconi/spfk-search/actions/workflows/ci.yml/badge.svg?branch=development)](https://github.com/ryanfrancesconi/spfk-search/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-search)](https://github.com/ryanfrancesconi/spfk-search/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)

A Swift package for fuzzy text search with query parsing, normalization, and configurable edit-distance scoring. Designed for matching user input against collections of searchable values — filenames, metadata tags, or any string fields.

Supports comma and space-delimited queries, automatic diacritic and case normalization, naive plural expansion, first-element weighting, and preset configurations for general search and type-ahead autocomplete.

## Usage

### Making a type searchable

Conform to the `Searchable` protocol by returning an array of strings. Place the most important field first — it receives a scoring boost.

```swift
import SPFKSearch

struct AudioFile: Searchable {
    let filename: String
    let artist: String
    let album: String

    var searchableValue: SearchableValue {
        [filename, artist, album]
    }
}
```

### Basic search

```swift
let file = AudioFile(filename: "stonehenge", artist: "spinal tap", album: "this is spinal tap")

let score = file.similarity(to: DelimitedQuery(string: "stonehenge"))
// score == 1.0 (exact match on first element)

let score2 = file.similarity(to: DelimitedQuery(string: "spinal"))
// score2 ≈ 0.9 (secondary element penalty)
```

### Custom minimum score

```swift
let score = file.similarity(
    to: DelimitedQuery(string: "haunted moon"),
    minimumScore: 0.1
)
```

### Autocomplete

```swift
let query = DelimitedQuery(string: "stone")
let score = file.similarity(to: query, matchConfig: QuerySearch.autocompleteConfig)
// Matches "stonehenge" with prefix weighting
```

### Direct QuerySearch

```swift
let search = QuerySearch(
    searchableValue: ["bird_colony", "nature sounds"],
    query: DelimitedQuery(string: "bird"),
    matchConfig: .init(
        minScore: 0.5,
        algorithm: .editDistance(QuerySearch.tightEditConfig)
    )
)

search.similarity  // 1.0 (first-element boost, clamped)
```

### Query parsing

```swift
// Space-delimited: keeps full phrase + individual words + singular variants
let q1 = DelimitedQuery(string: "dogs frogs")
q1.array  // ["dogs frogs", "dogs", "frogs", "dog", "frog"]

// Comma-delimited: individual terms only + singular variants
let q2 = DelimitedQuery(string: "birds, cats")
q2.array  // ["birds", "cats", "bird", "cat"]

// Normalization is automatic
let q3 = DelimitedQuery(string: "Café")
q3.array           // ["cafe"]
q3.originalString  // "Café"
```

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

## Dependencies

| Package | Purpose |
|---------|---------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | `UnitInterval`, foundation extensions, logging |
| [FuzzyMatch](https://github.com/ordo-one/FuzzyMatch) | Edit-distance scoring engine |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test utilities (test target only) |

## Requirements

- macOS 14+ / iOS 17+
- Swift 6.2+

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
