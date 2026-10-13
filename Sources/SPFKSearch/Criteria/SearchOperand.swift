// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// What a rule compares its field against, typed by the field's kind when parsed.
public indirect enum SearchOperand: Sendable, Hashable {
    case none
    case text(String)
    case number(Double)
    case bool(Bool)
    case list([String])
    case range(SearchOperand, SearchOperand)
    case date(SearchDate)
    case relative(amount: Int, unit: SearchCalendarUnit)
    case period(SearchCalendarUnit)
    /// Persisted sorted by `uuidString`, so one set chosen in two orders is one operand.
    case playlists([UUID])
}
