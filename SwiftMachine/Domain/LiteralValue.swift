//
//  LiteralValue.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

enum LiteralValue: Sendable, Codable, Equatable, Hashable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)

    nonisolated var type: PropertyType {
        switch self {
        case .string:
            return .string
        case .integer:
            return .integer
        case .double:
            return .double
        case .boolean:
            return .boolean
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PropertyType.self, forKey: .type)

        switch type {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .integer:
            self = .integer(try container.decode(Int.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        case .boolean:
            self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .model:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Literal values cannot decode model payload types."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .integer(let value):
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode(value, forKey: .value)
        }
    }
}
