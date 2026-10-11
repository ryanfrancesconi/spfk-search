// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

// Operands are typed by the resolved field's kind, so unit letters cannot collide: `m` is minutes
// on a duration, and nothing at all on a date.

extension SearchQueryParser {
    typealias Comparison = Result<(SearchOperator, SearchOperand), SearchQueryDiagnostic.Kind>

    static func textComparison(symbol: String, value: String) -> Comparison {
        let op: SearchOperator? = switch symbol {
        case "==", "=": .is
        case "!=": .isNot
        case "^=": .beginsWith
        case "$=": .endsWith
        default: nil
        }

        guard let op else { return .failure(.invalidOperator) }
        return .success((op, .text(value)))
    }

    static func numericComparison(symbol: String, value: String, kind: SearchFieldKind) -> Comparison {
        if let (lower, upper) = rangeBounds(value) {
            guard symbol == "==" || symbol == "=" else { return .failure(.invalidOperator) }
            guard let low = number(lower, kind: kind), let high = number(upper, kind: kind) else {
                return .failure(.invalidValue)
            }
            return .success((.between, .range(.number(low), .number(high))))
        }

        guard let op = orderedOperator(symbol) else { return .failure(.invalidOperator) }
        guard let number = number(value, kind: kind) else { return .failure(.invalidValue) }
        return .success((op, .number(number)))
    }

    static func dateComparison(symbol: String, value: String) -> Comparison {
        if let (lower, upper) = rangeBounds(value) {
            guard symbol == "==" || symbol == "=" else { return .failure(.invalidOperator) }
            guard let low = SearchDate(string: lower), let high = SearchDate(string: upper) else {
                return .failure(.invalidValue)
            }
            return .success((.between, .range(.date(low), .date(high))))
        }

        guard let op = orderedOperator(symbol) else { return .failure(.invalidOperator) }
        guard let date = SearchDate(string: value) else { return .failure(.invalidValue) }
        return .success((op, .date(date)))
    }

    static func boolComparison(symbol: String, value: String) -> Comparison {
        let flag: Bool? = switch value.lowercased() {
        case "true", "yes": true
        case "false", "no": false
        default: nil
        }

        guard let flag else { return .failure(.invalidValue) }

        switch symbol {
        case "==", "=": return .success((flag ? .isTrue : .isFalse, .none))
        case "!=": return .success((flag ? .isFalse : .isTrue, .none))
        default: return .failure(.invalidOperator)
        }
    }

    static func choiceComparison(symbol: String, value: String, kind: SearchFieldKind) -> Comparison {
        let op: SearchOperator? = switch symbol {
        case "==", "=": .is
        case "!=": .isNot
        default: nil
        }

        guard let op else { return .failure(.invalidOperator) }
        return choiceValue(value, kind: kind).map { (op, .text($0)) }
    }

    /// An enumeration option's persisted value, matched by value or title, or a color name.
    static func choiceValue(_ text: String, kind: SearchFieldKind) -> Result<String, SearchQueryDiagnostic.Kind> {
        switch kind {
        case let .enumeration(options):
            let match = options.first {
                $0.value.caseInsensitiveCompare(text) == .orderedSame || $0.title.caseInsensitiveCompare(text) == .orderedSame
            }
            return match.map { .success($0.value) } ?? .failure(.invalidValue)

        case .color:
            return ColorName(rawValue: text.lowercased()).map { .success($0.rawValue) } ?? .failure(.invalidValue)

        default:
            return .failure(.invalidOperator)
        }
    }

    /// `30d`, `2w`, `6mo`, `1y`.
    public static func relativeAmount(_ text: String) -> Result<SearchOperand, SearchQueryDiagnostic.Kind> {
        let (amount, suffix) = splitNumber(text)

        guard let amount, amount > 0, amount == amount.rounded() else { return .failure(.invalidValue) }

        let unit: SearchCalendarUnit? = switch suffix {
        case "d", "day", "days": .day
        case "w", "week", "weeks": .week
        case "mo", "month", "months": .month
        case "y", "year", "years": .year
        default: nil
        }

        guard let unit else { return .failure(.invalidValue) }
        return .success(.relative(amount: Int(amount), unit: unit))
    }

    public static func period(_ text: String) -> SearchCalendarUnit? {
        SearchCalendarUnit(rawValue: text.lowercased())
    }

    /// A number in the units `kind` reads: seconds for a duration, bytes for a size, hertz for a
    /// frequency.
    public static func number(_ text: String, kind: SearchFieldKind) -> Double? {
        let (number, suffix) = splitNumber(text)
        guard let number else { return nil }

        let multiplier: Double? = switch kind {
        case .duration:
            switch suffix {
            case "", "s": 1
            case "m": 60
            case "h": 3600
            default: nil
            }

        case .number(.bytes):
            // Decimal, as Finder and the file size column report sizes.
            switch suffix {
            case "", "b": 1
            case "kb": 1e3
            case "mb": 1e6
            case "gb": 1e9
            case "tb": 1e12
            default: nil
            }

        case .number(.hertz):
            switch suffix {
            case "", "hz": 1
            case "k", "khz": 1e3
            default: nil
            }

        default:
            suffix.isEmpty ? 1 : nil
        }

        return multiplier.map { number * $0 }
    }

    /// The leading number and the lowercased text after it.
    private static func splitNumber(_ text: String) -> (Double?, String) {
        let digits = text.prefix { $0.isASCII && ($0.isNumber || "+-.".contains($0)) }
        return (Double(digits), text.dropFirst(digits.count).lowercased())
    }

    /// `a..b` split into its bounds.
    private static func rangeBounds(_ text: String) -> (String, String)? {
        guard let separator = text.range(of: "..") else { return nil }
        let lower = String(text[..<separator.lowerBound])
        let upper = String(text[separator.upperBound...])
        guard lower.isNotEmpty, upper.isNotEmpty else { return nil }
        return (lower, upper)
    }

    private static func orderedOperator(_ symbol: String) -> SearchOperator? {
        switch symbol {
        case "==", "=": .is
        case "!=": .isNot
        case "<": .lessThan
        case "<=": .lessOrEqual
        case ">": .greaterThan
        case ">=": .greaterOrEqual
        default: nil
        }
    }
}
