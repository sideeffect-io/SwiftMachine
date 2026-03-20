//
//  PropertyDefaultValue.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

indirect enum PropertyDefaultValue: Sendable, Codable, Equatable, Hashable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case structValue(fields: [PropertyDefaultFieldValue])
    case enumCase(caseID: String, payload: PropertyDefaultValue?)

    var primitiveType: PropertyType? {
        switch self {
        case .string:
            return .string
        case .integer:
            return .integer
        case .double:
            return .double
        case .boolean:
            return .boolean
        case .structValue, .enumCase:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case kind
        case fields
        case caseID
        case payload
    }

    init(from decoder: Decoder) throws {
        if let legacyContainer = try? decoder.container(keyedBy: CodingKeys.self),
           let primitiveType = try? legacyContainer.decode(PropertyType.self, forKey: .type) {
            switch primitiveType {
            case .string:
                self = .string(try legacyContainer.decode(String.self, forKey: .value))
            case .integer:
                self = .integer(try legacyContainer.decode(Int.self, forKey: .value))
            case .double:
                self = .double(try legacyContainer.decode(Double.self, forKey: .value))
            case .boolean:
                self = .boolean(try legacyContainer.decode(Bool.self, forKey: .value))
            case .model:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: legacyContainer,
                    debugDescription: "Primitive defaults cannot decode model payload types."
                )
            }

            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)

        switch kind {
        case "struct":
            self = .structValue(
                fields: try container.decode([PropertyDefaultFieldValue].self, forKey: .fields)
            )
        case "enum":
            self = .enumCase(
                caseID: try container.decode(String.self, forKey: .caseID),
                payload: try container.decodeIfPresent(PropertyDefaultValue.self, forKey: .payload)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unsupported property default value kind '\(kind)'."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(PropertyType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .integer(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(PropertyType.integer, forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(PropertyType.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(PropertyType.boolean, forKey: .type)
            try container.encode(value, forKey: .value)
        case .structValue(let fields):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("struct", forKey: .kind)
            try container.encode(fields, forKey: .fields)
        case .enumCase(let caseID, let payload):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("enum", forKey: .kind)
            try container.encode(caseID, forKey: .caseID)
            try container.encodeIfPresent(payload, forKey: .payload)
        }
    }
}

struct PropertyDefaultFieldValue: Sendable, Codable, Equatable, Hashable, Identifiable {
    let fieldID: String
    let value: PropertyDefaultValue

    init(
        fieldID: String,
        value: PropertyDefaultValue
    ) {
        self.fieldID = fieldID
        self.value = value
    }

    var id: String {
        fieldID
    }
}
