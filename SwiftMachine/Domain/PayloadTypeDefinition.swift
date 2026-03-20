//
//  PayloadTypeDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct PayloadTypeDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let kind: PayloadTypeKind

    init(
        id: String = UUID().uuidString,
        name: String,
        kind: PayloadTypeKind
    ) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    var kindTitle: String {
        switch kind {
        case .structType:
            return "Struct"
        case .enumType:
            return "Enum"
        }
    }
}

enum PayloadTypeKind: Sendable, Codable, Equatable, Hashable {
    case structType(fields: [PropertyDefinition])
    case enumType(cases: [PayloadEnumCaseDefinition], defaultCaseID: String?)

    var fields: [PropertyDefinition] {
        switch self {
        case .structType(let fields):
            return fields
        case .enumType:
            return []
        }
    }

    var cases: [PayloadEnumCaseDefinition] {
        switch self {
        case .structType:
            return []
        case .enumType(let cases, _):
            return cases
        }
    }

    var defaultCaseID: String? {
        switch self {
        case .structType:
            return nil
        case .enumType(_, let defaultCaseID):
            return defaultCaseID
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case fields
        case cases
        case defaultCaseID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)

        switch kind {
        case "struct":
            self = .structType(
                fields: try container.decode([PropertyDefinition].self, forKey: .fields)
            )
        case "enum":
            self = .enumType(
                cases: try container.decode([PayloadEnumCaseDefinition].self, forKey: .cases),
                defaultCaseID: try container.decodeIfPresent(String.self, forKey: .defaultCaseID)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unsupported payload type kind '\(kind)'."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .structType(let fields):
            try container.encode("struct", forKey: .kind)
            try container.encode(fields, forKey: .fields)
        case .enumType(let cases, let defaultCaseID):
            try container.encode("enum", forKey: .kind)
            try container.encode(cases, forKey: .cases)
            try container.encodeIfPresent(defaultCaseID, forKey: .defaultCaseID)
        }
    }
}

struct PayloadEnumCaseDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let payloadType: PropertyType?

    init(
        id: String = UUID().uuidString,
        name: String,
        payloadType: PropertyType? = nil
    ) {
        self.id = id
        self.name = name
        self.payloadType = payloadType
    }
}
