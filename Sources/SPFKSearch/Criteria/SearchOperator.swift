// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A comparison a rule makes. The raw values are persisted.
public enum SearchOperator: String, Sendable, Hashable, CaseIterable {
    case contains
    case doesNotContain
    case `is`
    case isNot
    case beginsWith
    case endsWith
    case isEmpty
    case isNotEmpty
    case lessThan
    case lessOrEqual
    case greaterThan
    case greaterOrEqual
    case between
    case inTheLast
    case inThisPeriod
    case isAnyOf
    case isTrue
    case isFalse
}
