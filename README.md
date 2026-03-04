# SPFKSearch
Fuzzy text search library providing query parsing, normalization, and configurable scoring for matching user input against collections of searchable values.

## Features

- Fuzzy matching via edit-distance scoring with tunable configs
- Comma and space-delimited query parsing with automatic normalization
- Naive plural stripping to improve match recall (e.g. "birds" also tries "bird")
- Configurable minimum score thresholds and matching algorithms
- First-element weighting to prioritize primary fields (e.g. filename over metadata)
- Autocomplete-optimized config with prefix weighting and low edit distance
- `Searchable` protocol for conforming any type to the search system
- `Sendable` throughout for safe use in concurrent search pipelines

## Architecture

```
User Input ("haunted stonehenge moon")
    |
    v
DelimitedQuery
    |-- Detects delimiter (comma vs space)
    |-- Normalizes: case folding + diacritic removal
    |-- Splits into search terms: ["haunted stonehenge moon", "haunted", "stonehenge", "moon"]
    |-- Appends singular variants for words ending in 's'
    |
    v
QuerySearch
    |-- Pairs query terms against SearchableValue (array of strings)
    |-- Iterates all query terms x all searchable values
    |-- Delegates scoring to FuzzyMatcher (edit-distance algorithm)
    |-- Applies first-element boost (1.1x) / secondary penalty (0.9x)
    |-- Tracks top score across all pairs
    |
    v
UnitInterval (0.0 ... 1.0)

Searchable Protocol
    |-- Any type conforming to Searchable gets similarity() for free
    |-- Returns best match score against a DelimitedQuery
```

## Usage

### Making a Type Searchable

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

### Basic Search

```swift
let file = AudioFile(filename: "stonehenge", artist: "spinal tap", album: "this is spinal tap")

// Default config (minScore: 0.7, tight edit distance)
let score = file.similarity(to: DelimitedQuery(string: "stonehenge"))
// score == 1.0 (exact match on first element)
```

### Custom Minimum Score

```swift
// Lower threshold for broader matching
let score = file.similarity(
    to: DelimitedQuery(string: "haunted moon"),
    minimumScore: 0.1
)
```

### Autocomplete

```swift
// Prefix-weighted config for type-ahead suggestions
let query = DelimitedQuery(string: "stone")
let score = file.similarity(to: query, matchConfig: QuerySearch.autocompleteConfig)
// Matches "stonehenge" with prefix weighting
```

### Direct QuerySearch

```swift
let querySearch = QuerySearch(
    searchableValue: ["bird_colony", "cricket_chirp, insect"],
    query: DelimitedQuery(string: "bird"),
    matchConfig: .init(
        minScore: 0.5,
        algorithm: .editDistance(QuerySearch.tightEditConfig)
    )
)

print(querySearch.similarity) // 1.0 (first-element boost)
```

### Query Parsing

```swift
// Space-delimited: keeps full phrase + individual words
let q1 = DelimitedQuery(string: "dogs frogs")
// q1.array == ["dogs frogs", "dogs", "frogs", "dog", "frog"]

// Comma-delimited: splits into separate terms only
let q2 = DelimitedQuery(string: "cow, fish")
// q2.array == ["cow", "fish"]

// Normalization is automatic
let q3 = DelimitedQuery(string: "Café")
// q3.array == ["cafe"], q3.originalString == "Café"
```

## Preset Configs

| Config | Min Score | Algorithm | Use Case |
|--------|-----------|-----------|----------|
| `defaultConfig` | 0.7 | Tight edit distance | General search |
| `autocompleteConfig` | 0.6 | Edit distance (maxEdit: 1, prefixWeight: 2.0) | Type-ahead |
| `tightEditConfig` | — | High gap penalties, low bonuses | Strict matching |

## Dependencies

- **SPFKBase** - Foundation extensions, `UnitInterval`, logging
- **FuzzyMatch** ([ordo-one/FuzzyMatch](https://github.com/ordo-one/FuzzyMatch)) - Edit-distance scoring engine

## Requirements

- macOS 14+ / iOS 17+
- Swift 6.2+

