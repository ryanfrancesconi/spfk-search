// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import SPFKBase

extension SearchQueryParser {
    /// The word operators, which only count after a name the resolver knows.
    enum WordOperator {
        case isEmpty, isNotEmpty, inList, inLast, inThis

        /// Tokens after the field name, value excluded.
        var length: Int {
            switch self {
            case .isEmpty, .inLast, .inThis: 2
            case .isNotEmpty: 3
            case .inList: 1
            }
        }
    }

    /// A clause starting at the current token, or that token as free text.
    mutating func parseFieldOrText() -> SearchCriteria {
        let start = index
        let field = tokens[start]

        if let next = token(at: start + 1), next.kind == .symbol {
            return parseSymbolClause(field: field)
        }

        if let wordOperator = wordOperator(after: start), let resolution = resolver.resolveField(named: field.text) {
            return parseWordClause(resolution, wordOperator)
        }

        index += 1
        return .text(field.text)
    }

    private func wordOperator(after start: Int) -> WordOperator? {
        guard let first = token(at: start + 1) else { return nil }

        if first.isWord("is") {
            if token(at: start + 2)?.isWord("empty") == true { return .isEmpty }
            if token(at: start + 2)?.isWord("not") == true, token(at: start + 3)?.isWord("empty") == true {
                return .isNotEmpty
            }
        } else if first.isWord("in") {
            if token(at: start + 2)?.kind == .open { return .inList }
            if token(at: start + 2)?.isWord("last") == true, token(at: start + 3)?.isValue == true { return .inLast }
            if token(at: start + 2)?.isWord("this") == true, token(at: start + 3)?.isValue == true { return .inThis }
        }

        return nil
    }

    // MARK: - Symbol clauses

    private mutating func parseSymbolClause(field: SearchQueryToken) -> SearchCriteria {
        let start = index
        let symbol = tokens[start + 1].text

        guard let value = token(at: start + 2), value.isValue else {
            // `bpm:` with nothing after it is text, as it always was.
            index += 2
            return .text(sourceText(from: start, through: start + 1))
        }

        index += 3
        let text = sourceText(from: start, through: start + 2)

        guard let resolution = resolver.resolveField(named: field.text) else {
            if field.text.first?.isLetter == true {
                diagnose(.unknownField, field.range)
            }
            return .text(text)
        }

        switch Self.rule(resolution, symbol: symbol, value: value.text) {
        case let .success(rule):
            return .rule(rule)
        case let .failure(kind):
            diagnose(kind, field.range.lowerBound ..< value.range.upperBound)
            return .text(text)
        }
    }

    static func rule(
        _ resolution: SearchFieldResolution,
        symbol: String,
        value: String
    ) -> Result<SearchRule, SearchQueryDiagnostic.Kind> {
        let fieldID = resolution.fieldID

        switch symbol {
        case ":": return .success(SearchRule(fieldID: fieldID, op: .contains, operand: .text(value)))
        case "!:": return .success(SearchRule(fieldID: fieldID, op: .doesNotContain, operand: .text(value)))
        default: break
        }

        let typed: Result<(SearchOperator, SearchOperand), SearchQueryDiagnostic.Kind> = switch resolution.kind {
        case .text, .list:
            textComparison(symbol: symbol, value: value)
        case .number, .duration, .rating:
            numericComparison(symbol: symbol, value: value, kind: resolution.kind)
        case .date:
            dateComparison(symbol: symbol, value: value)
        case .bool:
            boolComparison(symbol: symbol, value: value)
        case .enumeration, .color:
            choiceComparison(symbol: symbol, value: value, kind: resolution.kind)
        case .playlist:
            .failure(.invalidOperator)
        }

        return typed.flatMap { op, operand in
            guard resolution.kind.operators.contains(op) else { return .failure(.invalidOperator) }
            return .success(SearchRule(fieldID: fieldID, op: op, operand: operand))
        }
    }

    // MARK: - Word clauses

    private mutating func parseWordClause(
        _ resolution: SearchFieldResolution,
        _ wordOperator: WordOperator
    ) -> SearchCriteria {
        let start = index
        let fieldID = resolution.fieldID
        var rule: Result<SearchRule, SearchQueryDiagnostic.Kind>
        var last = start + wordOperator.length

        switch wordOperator {
        case .isEmpty:
            rule = .success(SearchRule(fieldID: fieldID, op: .isEmpty))

        case .isNotEmpty:
            rule = .success(SearchRule(fieldID: fieldID, op: .isNotEmpty))

        case .inList:
            let open = start + 2
            let close = tokens[(open + 1)...].firstIndex { $0.kind == .close }
            last = close ?? tokens.count - 1
            let inner = close.map { tokens[open].range.upperBound ..< tokens[$0].range.lowerBound }
                ?? tokens[open].range.upperBound ..< source.endIndex
            rule = Self.listRule(resolution, items: Self.listItems(String(source[inner])))

        case .inLast:
            last += 1
            rule = Self.relativeAmount(tokens[last].text)
                .map { SearchRule(fieldID: fieldID, op: .inTheLast, operand: $0) }

        case .inThis:
            last += 1
            if let unit = Self.period(tokens[last].text) {
                rule = .success(SearchRule(fieldID: fieldID, op: .inThisPeriod, operand: .period(unit)))
            } else {
                rule = .failure(.invalidValue)
            }
        }

        if case let .success(value) = rule, !resolution.kind.operators.contains(value.op) {
            rule = .failure(.invalidOperator)
        }

        index = last + 1

        switch rule {
        case let .success(value):
            return .rule(value)
        case let .failure(kind):
            diagnose(kind, tokens[start].range.lowerBound ..< tokens[last].range.upperBound)
            return .text(sourceText(from: start, through: last))
        }
    }

    private static func listRule(
        _ resolution: SearchFieldResolution,
        items: [String]
    ) -> Result<SearchRule, SearchQueryDiagnostic.Kind> {
        guard items.isNotEmpty else { return .failure(.invalidValue) }

        var values: [String] = []
        for item in items {
            switch choiceValue(item, kind: resolution.kind) {
            case let .success(value): values.append(value)
            case let .failure(kind): return .failure(kind)
            }
        }

        return .success(SearchRule(fieldID: resolution.fieldID, op: .isAnyOf, operand: .list(values)))
    }

    /// `a, b, "c d"` split on commas, each trimmed and unquoted.
    static func listItems(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.count >= 2 && $0.hasPrefix("\"") && $0.hasSuffix("\"") ? String($0.dropFirst().dropLast()) : $0 }
            .filter(\.isNotEmpty)
    }
}
