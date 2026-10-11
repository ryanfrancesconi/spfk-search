// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// The type of a field's value, which decides the operators it offers and how operands parse.
public enum SearchFieldKind: Sendable, Hashable {
    case text
    case number(SearchUnit)
    case duration
    case date
    case bool
    case enumeration([SearchEnumOption])

    /// Several text values, such as keywords.
    case list

    /// 0–5.
    case rating

    /// Matched by `ColorName`.
    case color

    /// The operators a rule on this kind can use.
    ///
    /// `contains` and `doesNotContain` are also accepted for every kind from the legacy `:`,
    /// which compares the value's text.
    public var operators: [SearchOperator] {
        switch self {
        case .text:
            [.contains, .doesNotContain, .is, .isNot, .beginsWith, .endsWith, .isEmpty, .isNotEmpty]
        case .number, .duration, .rating:
            [.is, .isNot, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual, .between, .isEmpty, .isNotEmpty]
        case .date:
            [.is, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual, .between, .inTheLast, .inThisPeriod,
             .isEmpty, .isNotEmpty]
        case .bool:
            [.isTrue, .isFalse]
        case .enumeration, .color:
            [.is, .isNot, .isAnyOf, .isEmpty, .isNotEmpty]
        case .list:
            [.contains, .doesNotContain, .isEmpty, .isNotEmpty]
        }
    }
}
