// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// Any JSON value, kept verbatim so content this build does not understand survives a round trip.
public indirect enum SearchJSONValue: Sendable, Hashable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([SearchJSONValue])
    case object([String: SearchJSONValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try Self.probe(Bool.self, in: container) {
            self = .bool(value)
        } else if let value = try Self.probe(Double.self, in: container) {
            self = .number(value)
        } else if let value = try Self.probe(String.self, in: container) {
            self = .string(value)
        } else if let value = try Self.probe([SearchJSONValue].self, in: container) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: SearchJSONValue].self))
        }
    }

    /// `nil` only when the value is some other JSON type; anything else still throws.
    private static func probe<T: Decodable>(_ type: T.Type, in container: any SingleValueDecodingContainer) throws -> T? {
        do {
            return try container.decode(type)
        } catch DecodingError.typeMismatch {
            return nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }

    subscript(key: String) -> SearchJSONValue? {
        guard case let .object(object) = self else { return nil }
        return object[key]
    }

    var string: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var number: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    var int: Int? {
        guard let number, number == number.rounded(), abs(number) < Double(Int32.max) else { return nil }
        return Int(number)
    }
}
