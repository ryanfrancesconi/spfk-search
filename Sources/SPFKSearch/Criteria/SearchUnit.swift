// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// What a numeric field measures, which decides the suffixes its operands accept.
public enum SearchUnit: String, Sendable, Hashable, CaseIterable {
    case none
    case bpm
    case hertz
    case bytes
    case decibels
    case lufs
    case seconds
    case pixels
    case framesPerSecond
}
