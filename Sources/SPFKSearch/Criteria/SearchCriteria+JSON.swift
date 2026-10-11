// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

// The persisted form: one type-tagged object per node and operand. Every tag and key here is
// schema. Decoding never throws on content it does not recognize; the node becomes
// `SearchCriteria.unknown` and is written back as it was read.

extension SearchCriteria: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(json: try SearchJSONValue(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        try json.encode(to: encoder)
    }

    init(json: SearchJSONValue) {
        switch json["type"]?.string {
        case "group":
            if let conjunction = json["conjunction"]?.string.flatMap(SearchConjunction.init(rawValue:)),
               case let .array(children)? = json["children"]
            {
                self = .group(conjunction, children.map(SearchCriteria.init(json:)))
                return
            }
        case "rule":
            if let field = json["field"]?.string,
               let op = json["operator"]?.string.flatMap(SearchOperator.init(rawValue:)),
               let operand = json["operand"].flatMap(SearchOperand.init(json:))
            {
                self = .rule(SearchRule(fieldID: field, op: op, operand: operand))
                return
            }
        case "text":
            if let value = json["value"]?.string {
                self = .text(value)
                return
            }
        default:
            break
        }

        self = .unknown(json)
    }

    var json: SearchJSONValue {
        switch self {
        case let .group(conjunction, children):
            .object([
                "type": .string("group"),
                "conjunction": .string(conjunction.rawValue),
                "children": .array(children.map(\.json)),
            ])
        case let .rule(rule):
            .object([
                "type": .string("rule"),
                "field": .string(rule.fieldID),
                "operator": .string(rule.op.rawValue),
                "operand": rule.operand.json,
            ])
        case let .text(value):
            .object(["type": .string("text"), "value": .string(value)])
        case let .unknown(json):
            json
        }
    }
}

extension SearchOperand {
    init?(json: SearchJSONValue) {
        switch json["type"]?.string {
        case "none":
            self = .none
        case "text":
            guard let value = json["value"]?.string else { return nil }
            self = .text(value)
        case "number":
            guard let value = json["value"]?.number else { return nil }
            self = .number(value)
        case "bool":
            guard case let .bool(value)? = json["value"] else { return nil }
            self = .bool(value)
        case "list":
            guard case let .array(items)? = json["value"] else { return nil }
            let strings = items.compactMap(\.string)
            guard strings.count == items.count else { return nil }
            self = .list(strings)
        case "range":
            guard let lower = json["lower"].flatMap(SearchOperand.init(json:)),
                  let upper = json["upper"].flatMap(SearchOperand.init(json:))
            else { return nil }
            self = .range(lower, upper)
        case "date":
            guard let value = json["value"], let year = value["year"]?.int,
                  let date = SearchDate(year: year, month: value["month"]?.int, day: value["day"]?.int)
            else { return nil }
            self = .date(date)
        case "relative":
            guard let amount = json["amount"]?.int,
                  let unit = json["unit"]?.string.flatMap(SearchCalendarUnit.init(rawValue:))
            else { return nil }
            self = .relative(amount: amount, unit: unit)
        case "period":
            guard let unit = json["unit"]?.string.flatMap(SearchCalendarUnit.init(rawValue:)) else { return nil }
            self = .period(unit)
        case "playlist":
            guard let uuid = json["value"]?.string.flatMap(UUID.init(uuidString:)) else { return nil }
            self = .playlist(uuid)
        default:
            return nil
        }
    }

    var json: SearchJSONValue {
        switch self {
        case .none:
            .object(["type": .string("none")])
        case let .text(value):
            .object(["type": .string("text"), "value": .string(value)])
        case let .number(value):
            .object(["type": .string("number"), "value": .number(value)])
        case let .bool(value):
            .object(["type": .string("bool"), "value": .bool(value)])
        case let .list(values):
            .object(["type": .string("list"), "value": .array(values.map { .string($0) })])
        case let .range(lower, upper):
            .object(["type": .string("range"), "lower": lower.json, "upper": upper.json])
        case let .date(date):
            .object(["type": .string("date"), "value": date.json])
        case let .relative(amount, unit):
            .object(["type": .string("relative"), "amount": .number(Double(amount)), "unit": .string(unit.rawValue)])
        case let .period(unit):
            .object(["type": .string("period"), "unit": .string(unit.rawValue)])
        case let .playlist(uuid):
            .object(["type": .string("playlist"), "value": .string(uuid.uuidString)])
        }
    }
}

extension SearchDate {
    var json: SearchJSONValue {
        var object: [String: SearchJSONValue] = ["year": .number(Double(year))]
        if let month { object["month"] = .number(Double(month)) }
        if let day { object["day"] = .number(Double(day)) }
        return .object(object)
    }
}
