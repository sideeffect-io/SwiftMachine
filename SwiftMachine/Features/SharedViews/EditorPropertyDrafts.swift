//
//  EditorPropertyDrafts.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import Foundation

struct PropertyDefaultValueDraft: Equatable {
    var isEnabled: Bool
    var stringValue: String
    var integerValue: String
    var doubleValue: String
    var booleanValue: Bool

    nonisolated init(defaultValue: LiteralValue? = nil) {
        switch defaultValue {
        case .string(let value):
            isEnabled = true
            stringValue = value
            integerValue = ""
            doubleValue = ""
            booleanValue = false
        case .integer(let value):
            isEnabled = true
            stringValue = ""
            integerValue = String(value)
            doubleValue = ""
            booleanValue = false
        case .double(let value):
            isEnabled = true
            stringValue = ""
            integerValue = ""
            doubleValue = String(value)
            booleanValue = false
        case .boolean(let value):
            isEnabled = true
            stringValue = ""
            integerValue = ""
            doubleValue = ""
            booleanValue = value
        case nil:
            isEnabled = false
            stringValue = ""
            integerValue = ""
            doubleValue = ""
            booleanValue = false
        }
    }

    nonisolated func literalValue(for type: PropertyType) -> LiteralValue? {
        guard isEnabled else {
            return nil
        }

        switch type {
        case .string:
            return .string(stringValue)
        case .integer:
            guard let value = Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return .integer(value)
        case .double:
            guard let value = Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return .double(value)
        case .boolean:
            return .boolean(booleanValue)
        case .model:
            return nil
        }
    }

    nonisolated func validationMessage(
        for type: PropertyType,
        propertyName: String? = nil
    ) -> String? {
        guard isEnabled else {
            return nil
        }

        let trimmedPropertyName = propertyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = trimmedPropertyName.isEmpty ? "This property" : "Property '\(trimmedPropertyName)'"

        switch type {
        case .string, .boolean:
            return nil
        case .integer:
            guard Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                return "\(subject) needs a valid integer default value."
            }
            return nil
        case .double:
            guard Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                return "\(subject) needs a valid double default value."
            }
            return nil
        case .model:
            return nil
        }
    }
}

struct PropertyDefaultFieldDraft: Identifiable, Equatable {
    let field: ResolvedPropertyField
    var valueDraft: PropertyDefaultDraft

    var id: String {
        field.id
    }
}

struct PropertyDefaultPayloadDraft: Identifiable, Equatable {
    let id = "payload"
    var valueDraft: PropertyDefaultDraft
}

struct PropertyDefaultDraft: Equatable {
    let targetName: String
    let targetType: PropertyType
    let targetSchema: ResolvedPropertySchema
    var isEnabled: Bool
    var literalDraft: PropertyDefaultValueDraft
    var fieldDrafts: [PropertyDefaultFieldDraft]
    var selectedEnumCaseID: String?
    var payloadDrafts: [PropertyDefaultPayloadDraft]

    nonisolated init(
        targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        defaultValue: PropertyDefaultValue?,
        isRequired: Bool = false
    ) {
        self.targetName = targetName
        self.targetType = targetType
        self.targetSchema = targetSchema

        switch defaultValue {
        case .string(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .string(value))
        case .integer(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .integer(value))
        case .double(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .double(value))
        case .boolean(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .boolean(value))
        default:
            literalDraft = .init()
        }

        isEnabled = defaultValue != nil || isRequired

        switch targetSchema {
        case .primitive:
            fieldDrafts = []
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .structType(let fields):
            let existingFields: [String: PropertyDefaultFieldValue]
            if case .structValue(let storedFields) = defaultValue {
                existingFields = storedFields.reduce(into: [:]) { partialResult, field in
                    guard partialResult[field.fieldID] == nil else {
                        return
                    }

                    partialResult[field.fieldID] = field
                }
            } else {
                existingFields = [:]
            }

            fieldDrafts = fields.map { field in
                PropertyDefaultFieldDraft(
                    field: field,
                    valueDraft: PropertyDefaultDraft(
                        targetName: field.name,
                        targetType: field.type,
                        targetSchema: field.schema,
                        defaultValue: existingFields[field.id]?.value,
                        isRequired: !field.isOptional
                    )
                )
            }
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .enumType(let cases, let defaultCaseID):
            fieldDrafts = []

            if case .enumCase(let caseID, let payload) = defaultValue,
               cases.contains(where: { $0.id == caseID }) {
                selectedEnumCaseID = caseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: caseID,
                    cases: cases,
                    defaultValue: payload
                )
            } else {
                let preferredCaseID = defaultCaseID ?? cases.first?.id
                selectedEnumCaseID = preferredCaseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: preferredCaseID,
                    cases: cases,
                    defaultValue: nil
                )
            }
        }

        if isEnabled {
            activateEditorInputs()
        }
    }

    nonisolated var propertyDefaultValue: PropertyDefaultValue? {
        guard isEnabled else {
            return nil
        }

        switch targetSchema {
        case .primitive(let primitiveType):
            guard let literalValue = literalDraft.literalValue(for: primitiveType) else {
                return nil
            }

            switch literalValue {
            case .string(let value):
                return .string(value)
            case .integer(let value):
                return .integer(value)
            case .double(let value):
                return .double(value)
            case .boolean(let value):
                return .boolean(value)
            }

        case .structType:
            return .structValue(
                fields: fieldDrafts.compactMap { fieldDraft in
                    guard let fieldValue = fieldDraft.valueDraft.propertyDefaultValue else {
                        return nil
                    }

                    return PropertyDefaultFieldValue(
                        fieldID: fieldDraft.field.id,
                        value: fieldValue
                    )
                }
            )

        case .enumType:
            return .enumCase(
                caseID: selectedEnumCaseID ?? "",
                payload: payloadDrafts.first?.valueDraft.propertyDefaultValue
            )
        }
    }

    func validationMessage(propertyName: String) -> String? {
        guard isEnabled else {
            return nil
        }

        switch targetSchema {
        case .primitive(let primitiveType):
            return literalDraft.validationMessage(
                for: primitiveType,
                propertyName: propertyName
            )

        case .structType(let fields):
            let fieldDraftsByID = fieldDrafts.reduce(into: [String: PropertyDefaultFieldDraft]()) { partialResult, fieldDraft in
                partialResult[fieldDraft.field.id] = fieldDraft
            }

            for field in fields {
                guard let fieldDraft = fieldDraftsByID[field.id] else {
                    continue
                }

                if !field.isOptional && fieldDraft.valueDraft.propertyDefaultValue == nil {
                    return "Property '\(propertyName)' needs a default value for field '\(field.name)'."
                }

                if let childMessage = fieldDraft.valueDraft.validationMessage(propertyName: field.name) {
                    return childMessage
                }
            }

            return nil

        case .enumType(let cases, _):
            guard let selectedEnumCaseID,
                  let resolvedCase = cases.first(where: { $0.id == selectedEnumCaseID }) else {
                return "Property '\(propertyName)' needs a selected enum case."
            }

            guard resolvedCase.payloadSchema != nil else {
                return nil
            }

            guard let payloadDraft = payloadDrafts.first else {
                return "Property '\(propertyName)' needs a payload default for case '\(resolvedCase.name)'."
            }

            if payloadDraft.valueDraft.propertyDefaultValue == nil {
                return payloadDraft.valueDraft.validationMessage(propertyName: resolvedCase.name)
                    ?? "Property '\(propertyName)' needs a payload default for case '\(resolvedCase.name)'."
            }

            return payloadDraft.valueDraft.validationMessage(propertyName: resolvedCase.name)
        }
    }

    nonisolated mutating func selectEnumCase(
        _ caseID: String,
        cases: [ResolvedEnumCase]
    ) {
        selectedEnumCaseID = caseID
        let existingPayload = payloadDrafts.first?.valueDraft.propertyDefaultValue
        payloadDrafts = Self.payloadDrafts(
            caseID: caseID,
            cases: cases,
            defaultValue: existingPayload
        )
    }

    nonisolated mutating func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled

        guard isEnabled else {
            return
        }

        activateEditorInputs()
    }

    nonisolated private static func payloadDrafts(
        caseID: String?,
        cases: [ResolvedEnumCase],
        defaultValue: PropertyDefaultValue?
    ) -> [PropertyDefaultPayloadDraft] {
        guard let caseID,
              let resolvedCase = cases.first(where: { $0.id == caseID }),
              let payloadSchema = resolvedCase.payloadSchema else {
            return []
        }

        return [
            PropertyDefaultPayloadDraft(
                valueDraft: PropertyDefaultDraft(
                    targetName: resolvedCase.name,
                    targetType: resolvedCase.payloadType ?? .string,
                    targetSchema: payloadSchema,
                    defaultValue: defaultValue,
                    isRequired: true
                )
            )
        ]
    }

    nonisolated private mutating func activateEditorInputs() {
        switch targetSchema {
        case .primitive:
            literalDraft.isEnabled = true

        case .structType:
            for index in fieldDrafts.indices {
                guard fieldDrafts[index].valueDraft.isEnabled else {
                    continue
                }

                fieldDrafts[index].valueDraft.activateEditorInputs()
            }

        case .enumType:
            guard let firstPayloadIndex = payloadDrafts.indices.first else {
                return
            }

            payloadDrafts[firstPayloadIndex].valueDraft.setEnabled(true)
        }
    }
}

struct EditorPropertyDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var type: PropertyType
    var isOptional: Bool
    var defaultValue: PropertyDefaultDraft

    nonisolated init(
        id: String = UUID().uuidString,
        name: String = "",
        type: PropertyType = .string,
        isOptional: Bool = false,
        defaultValue: PropertyDefaultDraft? = nil
    ) {
        let fallbackDefaultValue = defaultValue ?? PropertyDefaultDraft(
            targetName: name,
            targetType: type,
            targetSchema: .primitive(type: type.isPrimitive ? type : .string),
            defaultValue: nil
        )
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = fallbackDefaultValue
    }

    nonisolated init(
        property: PropertyDefinition,
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        let schemaDefinition = propertySchemaDefinition(types: availableModelTypes)
        let propertySchema = schemaDefinition.schema(for: property.type)

        self.init(
            id: property.id,
            name: property.name,
            type: property.type,
            isOptional: property.isOptional,
            defaultValue: propertySchema.map { schema in
                PropertyDefaultDraft(
                    targetName: property.name,
                    targetType: property.type,
                    targetSchema: schema,
                    defaultValue: property.defaultValue
                )
            }
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var propertyDefinition: PropertyDefinition {
        PropertyDefinition(
            id: id,
            name: trimmedName,
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue.propertyDefaultValue
        )
    }

    var defaultValueValidationMessage: String? {
        defaultValue.validationMessage(
            propertyName: trimmedName
        )
    }

    mutating func reconfigureDefaultValue(
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        let schemaDefinition = propertySchemaDefinition(types: availableModelTypes)
        guard let propertySchema = schemaDefinition.schema(for: type) else {
            defaultValue = PropertyDefaultDraft(
                targetName: trimmedName.isEmpty ? name : trimmedName,
                targetType: type,
                targetSchema: .primitive(type: type.isPrimitive ? type : .string),
                defaultValue: nil
            )
            return
        }

        defaultValue = PropertyDefaultDraft(
            targetName: trimmedName.isEmpty ? name : trimmedName,
            targetType: type,
            targetSchema: propertySchema,
            defaultValue: defaultValue.propertyDefaultValue
        )
    }
}

extension Array where Element == EditorPropertyDraft {
    var propertyDefinitions: [PropertyDefinition] {
        map(\.propertyDefinition)
    }

    func validationMessage(
        emptyNameMessage: String,
        duplicateNameMessage: String
    ) -> String? {
        let trimmedPropertyNames = map(\.trimmedName)

        if trimmedPropertyNames.contains(where: \.isEmpty) {
            return emptyNameMessage
        }

        if Set(trimmedPropertyNames).count != trimmedPropertyNames.count {
            return duplicateNameMessage
        }

        if let defaultValueValidationMessage = compactMap(\.defaultValueValidationMessage).first {
            return defaultValueValidationMessage
        }

        return nil
    }
}

extension PropertyDefinition {
    nonisolated var editorLabel: String {
        editorLabel(typeDefinitions: [])
    }

    nonisolated func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        let baseLabel = "\(name): \(type.editorLabel(typeDefinitions: typeDefinitions))\(isOptional ? "?" : "")"

        guard let defaultValue else {
            return baseLabel
        }

        return "\(baseLabel) = \(defaultValue.editorValueLabel(for: type, typeDefinitions: typeDefinitions))"
    }
}

extension PropertyType {
    nonisolated func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        switch self {
        case .string, .integer, .double, .boolean:
            return rawValue
        case .model(let typeID):
            return typeDefinitions.first(where: { $0.id == typeID })?.name ?? "missing type"
        }
    }
}

extension PropertyDefaultDraft {
    nonisolated func payloadLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        switch targetSchema {
        case .primitive(let type):
            return "Payload: \(type.editorLabel(typeDefinitions: typeDefinitions))"
        case .structType:
            return "Payload fields"
        case .enumType:
            return "Nested enum payload"
        }
    }
}

private extension PropertyDefaultValue {
    nonisolated func editorValueLabel(
        for type: PropertyType,
        typeDefinitions: [PayloadTypeDefinition]
    ) -> String {
        let schemaDefinition = propertySchemaDefinition(types: typeDefinitions)
        let propertySchema = schemaDefinition.schema(for: type)

        switch self {
        case .string(let value):
            return String(reflecting: value)
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .structValue(let fields):
            guard case .structType(let resolvedFields)? = propertySchema else {
                return "{\(fields.count) field\(fields.count == 1 ? "" : "s")}"
            }

            let fieldNames = resolvedFields.reduce(into: [String: String]()) { partialResult, field in
                partialResult[field.id] = field.name
            }

            let summary = fields.map { field in
                fieldNames[field.fieldID] ?? "field"
            }
            .joined(separator: ", ")

            return "{\(summary)}"
        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _)? = propertySchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return ".unknown"
            }

            guard let payload else {
                return ".\(resolvedCase.name)"
            }

            let payloadType = resolvedCase.payloadType ?? .string
            return ".\(resolvedCase.name)(\(payload.editorValueLabel(for: payloadType, typeDefinitions: typeDefinitions)))"
        }
    }
}

nonisolated private func propertySchemaDefinition(
    types: [PayloadTypeDefinition]
) -> StateMachineDefinition {
    StateMachineDefinition(
        id: "property-defaults",
        name: "Property Defaults",
        initialStateID: "property-defaults-state",
        types: types,
        states: [],
        events: [],
        transitions: []
    )
}
