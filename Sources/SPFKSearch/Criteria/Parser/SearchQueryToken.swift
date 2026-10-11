// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

struct SearchQueryToken {
    enum Kind: Equatable {
        case word

        /// `text` holds the contents without the quotes.
        case quoted

        /// A comparison symbol such as `:` or `>=`.
        case symbol

        case open
        case close

        /// A number and a unit word merged into one rule, as in `120 bpm`.
        case inferred(fieldID: String)
    }

    var kind: Kind
    var text: String
    var range: Range<String.Index>

    var isValue: Bool {
        (kind == .word && !isKeyword) || kind == .quoted
    }

    var isKeyword: Bool {
        kind == .word && (text == "AND" || text == "OR" || text == "NOT")
    }

    func isKeyword(_ keyword: String) -> Bool {
        kind == .word && text == keyword
    }

    func isWord(_ word: String) -> Bool {
        kind == .word && text.caseInsensitiveCompare(word) == .orderedSame
    }

    /// A number as unit inference reads one: `120`, `-14`, `44.1`.
    var isNumber: Bool {
        guard kind == .word, let first = text.first, first.isNumber || "+-.".contains(first) else { return false }
        return Double(text) != nil
    }
}

// MARK: - Tokenizing

extension SearchQueryToken {
    static let symbols = ["!:", "!=", "==", "^=", "$=", ">=", "<=", ">", "<", "=", ":"]

    static func tokenize(_ source: String) -> [SearchQueryToken] {
        var tokens: [SearchQueryToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let character = source[index]

            if character.isWhitespace {
                index = source.index(after: index)

            } else if character == "(" || character == ")" {
                let next = source.index(after: index)
                tokens.append(.init(kind: character == "(" ? .open : .close, text: String(character), range: index ..< next))
                index = next

            } else if character == "\"" {
                let contentStart = source.index(after: index)
                let close = source[contentStart...].firstIndex(of: "\"")
                let end = close.map { source.index(after: $0) } ?? source.endIndex
                let content = String(source[contentStart ..< (close ?? source.endIndex)])
                tokens.append(.init(kind: .quoted, text: content, range: index ..< end))
                index = end

            } else if let symbol = symbol(at: index, in: source) {
                let end = source.index(index, offsetBy: symbol.count)
                tokens.append(.init(kind: .symbol, text: symbol, range: index ..< end))
                index = end

            } else {
                var end = index
                while end < source.endIndex, !endsWord(at: end, in: source) {
                    end = source.index(after: end)
                }
                tokens.append(.init(kind: .word, text: String(source[index ..< end]), range: index ..< end))
                index = end
            }
        }

        return tokens
    }

    private static func symbol(at index: String.Index, in source: String) -> String? {
        let rest = source[index...]
        return symbols.first { rest.hasPrefix($0) }
    }

    private static func endsWord(at index: String.Index, in source: String) -> Bool {
        let character = source[index]
        return character.isWhitespace || "()\"".contains(character) || symbol(at: index, in: source) != nil
    }

    /// Merges each unit word with an adjacent number into one `.inferred` token, preferring the
    /// number on its left (`120 bpm`) over the one on its right (`bpm 120`).
    ///
    /// A unit word beside a symbol is a field name in a clause (`bpm > 120`) and is left alone.
    static func inferUnits(in tokens: inout [SearchQueryToken], resolver: any SearchFieldResolving) {
        func isSymbol(_ index: Int) -> Bool {
            tokens.indices.contains(index) && tokens[index].kind == .symbol
        }

        var index = 0

        while index < tokens.count {
            defer { index += 1 }

            guard tokens[index].kind == .word, !isSymbol(index - 1), !isSymbol(index + 1),
                  let fieldID = resolver.resolveUnitWord(tokens[index].text)
            else { continue }

            let pair: ClosedRange<Int>
            if index > 0, tokens[index - 1].isNumber, !isSymbol(index - 2) {
                pair = index - 1 ... index
            } else if index + 1 < tokens.count, tokens[index + 1].isNumber, !isSymbol(index + 2) {
                pair = index ... index + 1
            } else {
                continue
            }

            let value = tokens[pair.lowerBound].isNumber ? tokens[pair.lowerBound].text : tokens[pair.upperBound].text
            let range = tokens[pair.lowerBound].range.lowerBound ..< tokens[pair.upperBound].range.upperBound
            tokens.replaceSubrange(pair, with: [.init(kind: .inferred(fieldID: fieldID), text: value, range: range)])
            index = pair.lowerBound
        }
    }
}
