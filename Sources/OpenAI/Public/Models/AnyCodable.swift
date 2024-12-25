import Foundation

public struct AnyCodable: Codable, Equatable {
    public let value: Any

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {

        switch lhs.value {
        case is NSNull:
            return rhs.value is NSNull
        case let lBoolValue as Bool:
            if let rBoolValue = rhs.value as? Bool { return lBoolValue == rBoolValue }
        case let lIntValue as Int:
            if let rIntValue = rhs.value as? Int { return lIntValue == rIntValue }
        case let lDoubleValue as Double:
            if let rDoubleValue = rhs.value as? Double { return lDoubleValue == rDoubleValue }
        case let lStringValue as String:
            if let rStringValue = rhs.value as? String { return lStringValue == rStringValue }
        case let lArrayValue as [Any]:
            let lAnyCodableArray = lArrayValue.map { AnyCodable($0) }
            if let rArrayValue = rhs.value as? [Any] {
                let rAnyCodableArray = rArrayValue.map { AnyCodable($0) }
                return lAnyCodableArray == rAnyCodableArray
            }
        case let lDictValue as [String: Any]:
            let lAnyCodableDict = lDictValue.mapValues { AnyCodable($0) }
            if let rDictValue = rhs.value as? [String: Any] {
                let rAnyCodableDict = rDictValue.mapValues { AnyCodable($0) }
                return lAnyCodableDict == rAnyCodableDict
            }
        default:
            return false
        }
        return false
    }

    public init(_ value: Any) {
        self.value = value
    }

    // MARK: - Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            // Decode nested arrays of AnyCodable
            self.value = arrayValue.map { $0.value }
        } else if let dictionaryValue = try? container.decode([String: AnyCodable].self) {
            // Decode nested dictionaries of AnyCodable
            self.value = dictionaryValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case is NSNull:
            try container.encodeNil()
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            let anyCodableArray = arrayValue.map { AnyCodable($0) }
            try container.encode(anyCodableArray)
        case let dictValue as [String: Any]:
            let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
            try container.encode(anyCodableDict)
        default:
            // Add further type checks/encodings if necessary
            throw EncodingError.invalidValue(
                self.value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

// Conform Array and Dictionary to Codable if the elements/values are AnyCodable
extension Array: Codable where Element == AnyCodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.unkeyedContainer()
        var items: [AnyCodable] = []
        var nestedContainer = container

        while !nestedContainer.isAtEnd {
            let item = try nestedContainer.decode(AnyCodable.self)
            items.append(item)
        }

        self = items
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for item in self {
            try container.encode(item)
        }
    }
}

extension Dictionary: Codable where Key == String, Value == AnyCodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        for key in container.allKeys {
            let decoded = try container.decode(AnyCodable.self, forKey: key)
            self[key.stringValue] = decoded
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        for (key, value) in self {
            guard let codingKey = CodingKeys(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }

    // Helper for Dictionary conformance
    struct CodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
}
