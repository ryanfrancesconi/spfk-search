# SPFKSearch

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-search)](https://github.com/ryanfrancesconi/spfk-search/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)

Matches what a user types against a media library. Both products' search
fields, smart playlists and find and replace are built on it.

It provides fuzzy free-text scoring that tolerates typos, case and diacritics; structured criteria,
field rules joined by `AND`, `OR` and `NOT`, parsed from typed text or built in a UI against a field
vocabulary the product supplies; find and replace over plain text; and expansion of a failed query to
related words within a vocabulary.

In free text, space-separated words must all match, while comma-separated terms are alternatives. A
type becomes searchable by listing its strings most important first, since the first is weighted
above the rest.

The index and store a search runs over belong to spfk-playlist-data and the products' data packages.
This package parses and scores; it holds no files.

## Constraints

- The encoded form of `SearchCriteria` is schema. Smart playlists persist it, so changing it is a
  migration.
- Synonym expansion is a fallback: run it only when the literal search found nothing, and score
  each way of reaching a result within its own band, below the literal one, or an inferred match
  outranks what the user typed. The master vocabulary is the labels of Apple's image and sound
  classifiers; a product adds its own subject matter's terms to it.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
