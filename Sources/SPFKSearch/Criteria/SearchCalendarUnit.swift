// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// The unit of a relative date or a calendar period. The raw values are persisted.
public enum SearchCalendarUnit: String, Sendable, Hashable, CaseIterable {
    case day
    case week
    case month
    case year

    public var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}
