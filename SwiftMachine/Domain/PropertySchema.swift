//
//  PropertySchema.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct PropertyValueReference: Sendable, Codable, Equatable, Hashable {
    let propertyID: String
    let path: [String]

    nonisolated init(
        propertyID: String,
        path: [String] = []
    ) {
        self.propertyID = propertyID
        self.path = path
    }
}

struct PropertyReferenceOption: Sendable, Equatable, Hashable, Identifiable {
    let reference: PropertyValueReference
    let pathNames: [String]
    let valueType: PropertyType
    let schema: ResolvedPropertySchema

    nonisolated var id: String {
        [
            reference.propertyID,
            reference.path.joined(separator: ".")
        ].joined(separator: "|")
    }

    nonisolated var leafName: String {
        pathNames.last ?? ""
    }
}

struct ResolvedPropertyField: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let schema: ResolvedPropertySchema
}

struct ResolvedEnumCase: Sendable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let payloadType: PropertyType?
    let payloadSchema: ResolvedPropertySchema?
}

indirect enum ResolvedPropertySchema: Sendable, Equatable, Hashable {
    case primitive(type: PropertyType)
    case structType(fields: [ResolvedPropertyField])
    case enumType(cases: [ResolvedEnumCase], defaultCaseID: String?)
}

extension PropertyValueReference {
    nonisolated static func == (lhs: PropertyValueReference, rhs: PropertyValueReference) -> Bool {
        lhs.propertyID == rhs.propertyID && lhs.path == rhs.path
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(propertyID)
        hasher.combine(path)
    }
}

extension ResolvedPropertyField {
    nonisolated static func == (lhs: ResolvedPropertyField, rhs: ResolvedPropertyField) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.isOptional == rhs.isOptional
            && lhs.schema == rhs.schema
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        type.hash(into: &hasher)
        hasher.combine(isOptional)
        schema.hash(into: &hasher)
    }
}

extension ResolvedEnumCase {
    nonisolated static func == (lhs: ResolvedEnumCase, rhs: ResolvedEnumCase) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.payloadType == rhs.payloadType
            && lhs.payloadSchema == rhs.payloadSchema
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        switch payloadType {
        case .some(let payloadType):
            hasher.combine(true)
            payloadType.hash(into: &hasher)
        case .none:
            hasher.combine(false)
        }

        switch payloadSchema {
        case .some(let payloadSchema):
            hasher.combine(true)
            payloadSchema.hash(into: &hasher)
        case .none:
            hasher.combine(false)
        }
    }
}

extension ResolvedPropertySchema {
    nonisolated static func == (lhs: ResolvedPropertySchema, rhs: ResolvedPropertySchema) -> Bool {
        switch (lhs, rhs) {
        case let (.primitive(lhsType), .primitive(rhsType)):
            return lhsType == rhsType
        case let (.structType(lhsFields), .structType(rhsFields)):
            return lhsFields == rhsFields
        case let (.enumType(lhsCases, lhsDefaultCaseID), .enumType(rhsCases, rhsDefaultCaseID)):
            return lhsCases == rhsCases && lhsDefaultCaseID == rhsDefaultCaseID
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .primitive(let type):
            hasher.combine(0)
            type.hash(into: &hasher)
        case .structType(let fields):
            hasher.combine(1)
            hasher.combine(fields.count)
            for field in fields {
                field.hash(into: &hasher)
            }
        case .enumType(let cases, let defaultCaseID):
            hasher.combine(2)
            hasher.combine(cases.count)
            for payloadCase in cases {
                payloadCase.hash(into: &hasher)
            }
            hasher.combine(defaultCaseID)
        }
    }
}

extension StateMachineDefinition {
    nonisolated func payloadTypeDefinition(id: String) -> PayloadTypeDefinition? {
        types.first(where: { $0.id == id })
    }

    nonisolated func schema(for type: PropertyType) -> ResolvedPropertySchema? {
        schema(for: type, visitedTypeIDs: [])
    }

    nonisolated func schema(for property: PropertyDefinition) -> ResolvedPropertySchema? {
        schema(for: property.type)
    }

    nonisolated func schema(
        for reference: PropertyValueReference,
        in properties: [PropertyDefinition]
    ) -> ResolvedPropertySchema? {
        guard let property = properties.first(where: { $0.id == reference.propertyID }),
              var currentSchema = schema(for: property) else {
            return nil
        }

        for componentID in reference.path {
            switch currentSchema {
            case .primitive:
                return nil
            case .structType(let fields):
                guard let field = fields.first(where: { $0.id == componentID }) else {
                    return nil
                }
                currentSchema = field.schema
            case .enumType:
                return nil
            }
        }

        return currentSchema
    }

    nonisolated func propertyType(
        for reference: PropertyValueReference,
        in properties: [PropertyDefinition]
    ) -> PropertyType? {
        guard let property = properties.first(where: { $0.id == reference.propertyID }) else {
            return nil
        }

        guard !reference.path.isEmpty else {
            return property.type
        }

        guard var currentSchema = schema(for: property) else {
            return nil
        }

        var currentType = property.type

        for componentID in reference.path {
            switch currentSchema {
            case .primitive, .enumType:
                return nil
            case .structType(let fields):
                guard let field = fields.first(where: { $0.id == componentID }) else {
                    return nil
                }

                currentType = field.type
                currentSchema = field.schema
            }
        }

        return currentType
    }

    nonisolated func typeDisplayName(for type: PropertyType) -> String {
        switch type {
        case .string, .integer, .double, .boolean:
            return type.title.lowercased()
        case .model(let typeID):
            return payloadTypeDefinition(id: typeID)?.name ?? "missing type"
        }
    }

    nonisolated func referenceOptions(in properties: [PropertyDefinition]) -> [PropertyReferenceOption] {
        properties.compactMap { property -> (PropertyDefinition, PropertyType, ResolvedPropertySchema)? in
            guard let schema = schema(for: property) else {
                return nil
            }

            return (property, property.type, schema)
        }
        .flatMap { property, type, schema in
            referenceOptions(
                for: schema,
                valueType: type,
                propertyID: property.id,
                pathIDs: [],
                pathNames: [property.name]
            )
        }
    }

    nonisolated private func schema(
        for type: PropertyType,
        visitedTypeIDs: Set<String>
    ) -> ResolvedPropertySchema? {
        switch type {
        case .string, .integer, .double, .boolean:
            return .primitive(type: type)

        case .model(let typeID):
            guard let definition = payloadTypeDefinition(id: typeID) else {
                return nil
            }

            guard !visitedTypeIDs.contains(typeID) else {
                return nil
            }

            var nextVisitedTypeIDs = visitedTypeIDs
            nextVisitedTypeIDs.insert(typeID)

            switch definition.kind {
            case .structType(let fields):
                let resolvedFields = fields.compactMap { field -> ResolvedPropertyField? in
                    guard let fieldSchema = schema(
                        for: field.type,
                        visitedTypeIDs: nextVisitedTypeIDs
                    ) else {
                        return nil
                    }

                    return ResolvedPropertyField(
                        id: field.id,
                        name: field.name,
                        type: field.type,
                        isOptional: field.isOptional,
                        schema: fieldSchema
                    )
                }

                guard resolvedFields.count == fields.count else {
                    return nil
                }

                return .structType(fields: resolvedFields)

            case .enumType(let cases, let defaultCaseID):
                let resolvedCases = cases.compactMap { payloadCase -> ResolvedEnumCase? in
                    let payloadSchema = payloadCase.payloadType.flatMap { payloadType in
                        schema(
                            for: payloadType,
                            visitedTypeIDs: nextVisitedTypeIDs
                        )
                    }

                    if payloadCase.payloadType != nil && payloadSchema == nil {
                        return nil
                    }

                    return ResolvedEnumCase(
                        id: payloadCase.id,
                        name: payloadCase.name,
                        payloadType: payloadCase.payloadType,
                        payloadSchema: payloadSchema
                    )
                }

                guard resolvedCases.count == cases.count else {
                    return nil
                }

                return .enumType(
                    cases: resolvedCases,
                    defaultCaseID: defaultCaseID
                )
            }
        }
    }

    nonisolated private func referenceOptions(
        for schema: ResolvedPropertySchema,
        valueType: PropertyType,
        propertyID: String,
        pathIDs: [String],
        pathNames: [String]
    ) -> [PropertyReferenceOption] {
        let root = PropertyReferenceOption(
            reference: PropertyValueReference(
                propertyID: propertyID,
                path: pathIDs
            ),
            pathNames: pathNames,
            valueType: valueType,
            schema: schema
        )

        switch schema {
        case .primitive, .enumType:
            return [root]

        case .structType(let fields):
            let childOptions = fields.flatMap { field in
                referenceOptions(
                    for: field.schema,
                    valueType: field.type,
                    propertyID: propertyID,
                    pathIDs: pathIDs + [field.id],
                    pathNames: pathNames + [field.name]
                )
            }

            return [root] + childOptions
        }
    }
}
