# SPFKSearch

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-search)](https://github.com/ryanfrancesconi/spfk-search/tags)
[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-search%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-search)

Text search for media libraries: fuzzy scoring of free text, structured search criteria, find and
replace, and synonym expansion. It parses and scores; it does not store or index files.

## Features

- Fuzzy matching that tolerates typos, case and diacritics
- Space-separated words must all match; comma-separated terms are alternatives
- A type becomes searchable by listing its strings, most important first (`Searchable`)
- Structured criteria (`SearchCriteria`) built in code or parsed from typed text with `AND`, `OR`
  and `NOT`, against a field vocabulary the caller supplies
- Find and replace over plain text (`TextReplacer`)
- Expansion of a query to related words within a vocabulary (`SynonymExpander`)

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
