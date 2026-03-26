//
//  PropertyType.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

enum PropertyType: Sendable, Codable, Equatable, Hashable {
    case string
    case integer
    case double
    case boolean
    case model(typeID: String)

    static let primitiveCases: [PropertyType] = [
        .string,
        .integer,
        .double,
        .boolean
    ]

    nonisolated var rawValue: String {
        switch self {
        case .string:
            return "string"
        case .integer:
            return "integer"
        case .double:
            return "double"
        case .boolean:
            return "boolean"
        case .model(let typeID):
            return "model:\(typeID)"
        }
    }

    nonisolated var title: String {
        switch self {
        case .string:
            return "String"
        case .integer:
            return "Integer"
        case .double:
            return "Double"
        case .boolean:
            return "Boolean"
        case .model:
            return "Model"
        }
    }

    nonisolated var isPrimitive: Bool {
        switch self {
        case .string, .integer, .double, .boolean:
            return true
        case .model:
            return false
        }
    }

    nonisolated var referencedTypeID: String? {
        guard case .model(let typeID) = self else {
            return nil
        }

        return typeID
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case typeID
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let primitiveKind = try? container.decode(String.self) {
            switch primitiveKind {
            case "string":
                self = .string
                return
            case "integer":
                self = .integer
                return
            case "double":
                self = .double
                return
            case "boolean":
                self = .boolean
                return
            default:
                break
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)

        switch kind {
        case "string":
            self = .string
        case "integer":
            self = .integer
        case "double":
            self = .double
        case "boolean":
            self = .boolean
        case "model":
            self = .model(typeID: try container.decode(String.self, forKey: .typeID))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unsupported property type '\(kind)'."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .string, .integer, .double, .boolean:
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        case .model(let typeID):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("model", forKey: .kind)
            try container.encode(typeID, forKey: .typeID)
        }
    }

    nonisolated static func == (lhs: PropertyType, rhs: PropertyType) -> Bool {
        switch (lhs, rhs) {
        case (.string, .string), (.integer, .integer), (.double, .double), (.boolean, .boolean):
            return true
        case let (.model(lhsTypeID), .model(rhsTypeID)):
            return lhsTypeID == rhsTypeID
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .string:
            hasher.combine(0)
        case .integer:
            hasher.combine(1)
        case .double:
            hasher.combine(2)
        case .boolean:
            hasher.combine(3)
        case .model(let typeID):
            hasher.combine(4)
            hasher.combine(typeID)
        }
    }
}
