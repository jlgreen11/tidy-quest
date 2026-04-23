import Foundation

/// Type-erased Codable value for `jsonb` columns (settings, payload, etc.).
/// Supports JSON primitive types: null, bool, number, string, array, object.
public struct AnyCodable: Codable, Sendable, Hashable {
    public let value: any Sendable

    public init(_ value: some Sendable) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = Optional<String>.none as any Sendable
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnyCodable type")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [AnyCodable]:
            try container.encode(v)
        case let v as [String: AnyCodable]:
            try container.encode(v)
        default:
            try container.encodeNil()
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Compare via round-trip JSON for structural equality
        guard let lData = try? JSONEncoder().encode(lhs),
              let rData = try? JSONEncoder().encode(rhs) else { return false }
        return lData == rData
    }

    public func hash(into hasher: inout Hasher) {
        if let data = try? JSONEncoder().encode(self) {
            hasher.combine(data)
        }
    }
}
