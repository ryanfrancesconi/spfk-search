// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// Turns typed search text into SearchCriteria.
///
/// `AND`, `OR` and `NOT` are keywords only in upper case; juxtaposition means `AND`, and `-`
/// before a word that is not a number means `NOT`. A clause is `field op value`, where the field
/// is whatever the resolver recognizes, and its value is typed by that field's kind. Anything that
/// is not a clause is free text, so an unknown field name is searched rather than dropped.
public struct SearchQueryParser {
    let source: String
    let resolver: any SearchFieldResolving
    var tokens: [SearchQueryToken]
    var index = 0
    var diagnostics: [SearchQueryDiagnostic] = []

    public static func parse(_ text: String, resolver: any SearchFieldResolving) -> SearchQueryParseResult {
        var tokens = SearchQueryToken.tokenize(text)
        SearchQueryToken.inferUnits(in: &tokens, resolver: resolver)

        var parser = SearchQueryParser(source: text, resolver: resolver, tokens: tokens)
        let criteria = parser.parseQuery()
        return SearchQueryParseResult(criteria: criteria, diagnostics: parser.diagnostics)
    }

    // MARK: - Grammar

    mutating func parseQuery() -> SearchCriteria {
        var parts: [SearchCriteria] = []

        while index < tokens.count {
            parts.append(parseOr())

            if let token = token(at: index), token.kind == .close {
                diagnose(.unbalancedParenthesis, token.range)
                index += 1
            }
        }

        return Self.all(parts)
    }

    private mutating func parseOr() -> SearchCriteria {
        var branches = [parseAnd()]

        while let token = token(at: index), token.isKeyword("OR") {
            index += 1
            branches.append(parseAnd())
        }

        branches.removeAll(where: \.isEmpty)

        switch branches.count {
        case 0: return .empty
        case 1: return branches[0]
        default: return .group(.any, branches)
        }
    }

    private mutating func parseAnd() -> SearchCriteria {
        var items: [SearchCriteria] = []

        while let token = token(at: index), token.kind != .close, !token.isKeyword("OR") {
            if token.isKeyword("AND") {
                index += 1
                continue
            }

            items.append(parseUnary())
        }

        return Self.all(items)
    }

    private mutating func parseUnary() -> SearchCriteria {
        guard let token = token(at: index) else { return .empty }

        if token.isKeyword("NOT") {
            index += 1
            guard let next = self.token(at: index), next.kind != .close, !next.isKeyword("OR") else {
                return .text(token.text)
            }
            return .group(.none, [parseUnary()])
        }

        if token.kind == .word, token.text.hasPrefix("-") {
            if let negated = parseDash(token) { return negated }
        }

        switch token.kind {
        case .open:
            index += 1
            let inner = parseOr()
            if let close = self.token(at: index), close.kind == .close {
                index += 1
            } else {
                diagnose(.unbalancedParenthesis, token.range)
            }
            return inner

        case let .inferred(fieldID):
            index += 1
            return .rule(SearchRule(fieldID: fieldID, op: .contains, operand: .text(token.text)))

        case .word, .quoted:
            return parseFieldOrText()

        case .symbol, .close:
            index += 1
            return .text(token.text)
        }
    }

    /// `-word` as `NOT word`, or `nil` when the dash belongs to the word: a number such as `-14`.
    private mutating func parseDash(_ token: SearchQueryToken) -> SearchCriteria? {
        let rest = token.text.dropFirst()

        if rest.isEmpty {
            // A lone dash negates whatever touches it, as in `-"rain on leaves"` or `-(a OR b)`.
            guard let next = self.token(at: index + 1), next.kind != .close,
                  next.range.lowerBound == token.range.upperBound
            else {
                return nil
            }
            index += 1
            return .group(.none, [parseUnary()])
        }

        guard let first = rest.first, !first.isNumber, first != "." else { return nil }

        tokens[index].text = String(rest)
        tokens[index].range = source.index(after: token.range.lowerBound) ..< token.range.upperBound
        return .group(.none, [parseUnary()])
    }

    // MARK: - Helpers

    func token(at index: Int) -> SearchQueryToken? {
        tokens.indices.contains(index) ? tokens[index] : nil
    }

    /// The source text from the start of one token to the end of another, as the user typed it.
    func sourceText(from first: Int, through last: Int) -> String {
        String(source[tokens[first].range.lowerBound ..< tokens[last].range.upperBound])
    }

    mutating func diagnose(_ kind: SearchQueryDiagnostic.Kind, _ range: Range<String.Index>) {
        diagnostics.append(SearchQueryDiagnostic(kind: kind, range: range))
    }

    /// `items` joined by `AND`, with nested `AND` groups flattened and empty ones dropped.
    public static func all(_ items: [SearchCriteria]) -> SearchCriteria {
        let flattened: [SearchCriteria] = items.flatMap { item -> [SearchCriteria] in
            if case let .group(.all, children) = item { return children }
            return [item]
        }

        switch flattened.count {
        case 0: return .empty
        case 1: return flattened[0]
        default: return .group(.all, flattened)
        }
    }
}
