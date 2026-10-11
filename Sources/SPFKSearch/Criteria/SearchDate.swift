// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// A date at the precision it was written: a year, a month or a day.
///
/// Compared as the interval it covers, so `2019` is the whole year and contains `2019-04`.
public struct SearchDate: Sendable, Hashable {
    public let year: Int
    public let month: Int?

    /// Only present with a month.
    public let day: Int?

    public init?(year: Int, month: Int? = nil, day: Int? = nil) {
        guard (1 ... 9999).contains(year) else { return nil }
        if let month { guard (1 ... 12).contains(month) else { return nil } }
        if let day { guard month != nil, (1 ... 31).contains(day) else { return nil } }

        self.year = year
        self.month = month
        self.day = day
    }

    /// `yyyy`, `yyyy-MM` or `yyyy-MM-dd`, separated by `-`, `/` or `.`.
    public init?(string: String) {
        guard let (date, rest) = Self.scan(Substring(string.trimmingCharacters(in: .whitespaces))),
              rest.isEmpty
        else { return nil }

        self = date
    }

    /// The date a longer value starts with, such as a tag holding `2019-04-12T10:22:00Z`.
    ///
    /// A time after the date is dropped, so a timestamp compares as its day.
    public static func leading(in string: String) -> SearchDate? {
        guard let (date, rest) = scan(Substring(string.trimmingCharacters(in: .whitespaces))) else { return nil }
        guard rest.isEmpty || rest.first == "T" || rest.first == " " else { return nil }
        return date
    }

    /// The span this date covers in `calendar`, half-open at its end.
    public func interval(in calendar: Calendar) -> DateInterval? {
        let components = DateComponents(year: year, month: month ?? 1, day: day ?? 1)
        guard let start = calendar.date(from: components) else { return nil }

        let unit: Calendar.Component = day != nil ? .day : month != nil ? .month : .year
        return calendar.dateInterval(of: unit, for: start)
    }

    private static func scan(_ text: Substring) -> (SearchDate, Substring)? {
        var rest = text

        guard let year = takeDigits(&rest, count: 4 ... 4) else { return nil }
        guard let separator = rest.first, "-/.".contains(separator) else {
            return SearchDate(year: year).map { ($0, rest) }
        }

        rest.removeFirst()
        guard let month = takeDigits(&rest, count: 1 ... 2) else { return nil }
        guard rest.first == separator else {
            return SearchDate(year: year, month: month).map { ($0, rest) }
        }

        rest.removeFirst()
        guard let day = takeDigits(&rest, count: 1 ... 2) else { return nil }
        return SearchDate(year: year, month: month, day: day).map { ($0, rest) }
    }

    private static func takeDigits(_ text: inout Substring, count: ClosedRange<Int>) -> Int? {
        let digits = text.prefix { $0.isASCII && $0.isNumber }
        guard count.contains(digits.count), let value = Int(digits) else { return nil }
        text.removeFirst(digits.count)
        return value
    }
}
