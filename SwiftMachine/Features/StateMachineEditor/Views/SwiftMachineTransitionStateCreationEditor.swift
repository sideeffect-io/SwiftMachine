//
//  SwiftMachineTransitionStateCreationEditor.swift
//  SwiftMachine
//
//  Created by Codex on 17/03/2026.
//

import SwiftUI

struct TransitionTargetStateCreationDraft: Equatable {
    var propertyDrafts: [TransitionTargetStatePropertyDraft]

    init(
        existingCreation: TransitionTargetStateCreation,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition],
        targetProperties: [PropertyDefinition],
        typeDefinitions: [PayloadTypeDefinition]
    ) {
        let schemaDefinition = StateMachineDefinition(
            id: "transition-draft",
            name: "Transition Draft",
            initialStateID: "transition-draft-state",
            types: typeDefinitions,
            states: [],
            events: [],
            transitions: []
        )
        let sourceOptions = schemaDefinition.referenceOptions(in: sourceProperties)
        let eventOptions = schemaDefinition.referenceOptions(in: eventProperties)
        let existingAssignments = existingCreation.assignments.reduce(
            into: [String: TransitionTargetStatePropertyAssignment]()
        ) { partialResult, assignment in
            guard partialResult[assignment.targetPropertyID] == nil else {
                return
            }

            partialResult[assignment.targetPropertyID] = assignment
        }

        propertyDrafts = targetProperties.compactMap { targetProperty in
            guard let targetSchema = schemaDefinition.schema(for: targetProperty) else {
                return nil
            }

            return TransitionTargetStatePropertyDraft(
                targetProperty: targetProperty,
                typeDefinitions: typeDefinitions,
                valueDraft: TransitionValueDraft(
                    targetName: targetProperty.name,
                    targetType: targetProperty.type,
                    targetSchema: targetSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions,
                    existingValueSource: existingAssignments[targetProperty.id]?.valueSource
                )
            )
        }
    }

    var targetStateCreation: TransitionTargetStateCreation {
        TransitionTargetStateCreation(
            assignments: propertyDrafts.map(\.assignment)
        )
    }

    var validationMessage: String? {
        propertyDrafts.compactMap(\.validationMessage).first
    }
}

struct TransitionTargetStateCreationEditorView: View {
    let sourceStateName: String
    let sourceProperties: [PropertyDefinition]
    let eventName: String
    let eventProperties: [PropertyDefinition]
    let targetStateName: String
    let targetProperties: [PropertyDefinition]
    let typeDefinitions: [PayloadTypeDefinition]
    @Binding var draft: TransitionTargetStateCreationDraft

    private var schemaDefinition: StateMachineDefinition {
        StateMachineDefinition(
            id: "transition-editor",
            name: "Transition Editor",
            initialStateID: "transition-editor-state",
            types: typeDefinitions,
            states: [],
            events: [],
            transitions: []
        )
    }

    private var sourceOptions: [PropertyReferenceOption] {
        schemaDefinition.referenceOptions(in: sourceProperties)
    }

    private var eventOptions: [PropertyReferenceOption] {
        schemaDefinition.referenceOptions(in: eventProperties)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create \(targetStateName) by deciding how each target property is filled from the source state, the event, target defaults, or explicit enum construction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if targetProperties.isEmpty {
                Label("\(targetStateName) has no payload properties. Entering the state needs no additional mapping.", systemImage: "tray")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                mappingContext

                VStack(alignment: .leading, spacing: 10) {
                    ForEach($draft.propertyDrafts) { $propertyDraft in
                        TransitionValueDraftRowView(
                            title: propertyDraft.targetProperty.name,
                            subtitle: propertyDraft.targetProperty.editorLabel(typeDefinitions: typeDefinitions),
                            draft: $propertyDraft.valueDraft,
                            sourceStateName: sourceStateName,
                            sourceOptions: sourceOptions,
                            eventName: eventName,
                            eventOptions: eventOptions,
                            typeDefinitions: typeDefinitions
                        )
                    }
                }
            }

            if let validationMessage = draft.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var mappingContext: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sourceProperties.isEmpty {
                Text("Source \(sourceStateName) has no payload properties.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Source \(sourceStateName): \(sourceProperties.map(\.name).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if eventProperties.isEmpty {
                Text("Event \(eventName) has no payload properties.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Event \(eventName): \(eventProperties.map(\.name).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TransitionTargetStatePropertyDraft: Identifiable, Equatable {
    let targetProperty: PropertyDefinition
    let typeDefinitions: [PayloadTypeDefinition]
    var valueDraft: TransitionValueDraft

    var id: String {
        targetProperty.id
    }

    var assignment: TransitionTargetStatePropertyAssignment {
        TransitionTargetStatePropertyAssignment(
            targetPropertyID: targetProperty.id,
            valueSource: valueDraft.valueSource
        )
    }

    var validationMessage: String? {
        valueDraft.validationMessage(propertyName: targetProperty.name)
    }
}

struct TransitionFieldDraft: Identifiable, Equatable {
    let field: ResolvedPropertyField
    var valueDraft: TransitionValueDraft

    var id: String {
        field.id
    }
}

struct TransitionPayloadDraft: Identifiable, Equatable {
    let id = "payload"
    var valueDraft: TransitionValueDraft
}

struct TransitionValueDraft: Equatable {
    let targetName: String
    let targetType: PropertyType
    let targetSchema: ResolvedPropertySchema
    var selectedChoice: TransitionValueChoice
    var literalDraft: PropertyDefaultValueDraft
    var customCommentDraft: String
    var fieldDrafts: [TransitionFieldDraft]
    var selectedEnumCaseID: String?
    var payloadDrafts: [TransitionPayloadDraft]

    init(
        targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption],
        existingValueSource: TransitionTargetStateValueSource?
    ) {
        let suggestedChoice = Self.suggestedChoice(
            for: targetName,
            targetType: targetType,
            targetSchema: targetSchema,
            sourceOptions: sourceOptions,
            eventOptions: eventOptions
        )

        let selectedChoice = existingValueSource.flatMap(Self.choice(for:)) ?? suggestedChoice
        self.targetName = targetName
        self.targetType = targetType
        self.targetSchema = targetSchema
        self.selectedChoice = selectedChoice

        switch existingValueSource {
        case .literal(let literalValue):
            literalDraft = PropertyDefaultValueDraft(defaultValue: literalValue)
            customCommentDraft = ""
        case .custom(let comment):
            literalDraft = .init()
            customCommentDraft = comment
        default:
            literalDraft = Self.defaultLiteralDraft(for: targetSchema)
            customCommentDraft = ""
        }

        switch targetSchema {
        case .primitive:
            fieldDrafts = []
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .structType(let fields):
            let existingFields: [String: TransitionTargetStateFieldAssignment]
            if case .fieldMap(let assignments) = existingValueSource {
                existingFields = assignments.reduce(into: [:]) { partialResult, assignment in
                    guard partialResult[assignment.fieldID] == nil else {
                        return
                    }

                    partialResult[assignment.fieldID] = assignment
                }
            } else {
                existingFields = [:]
            }

            fieldDrafts = fields.map { field in
                TransitionFieldDraft(
                    field: field,
                    valueDraft: TransitionValueDraft(
                        targetName: field.name,
                        targetType: field.type,
                        targetSchema: field.schema,
                        sourceOptions: sourceOptions,
                        eventOptions: eventOptions,
                        existingValueSource: existingFields[field.id]?.valueSource
                    )
                )
            }
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .enumType(let cases, let defaultCaseID):
            fieldDrafts = []

            if case .enumCase(let caseID, let payload) = existingValueSource,
               cases.contains(where: { $0.id == caseID }) {
                selectedEnumCaseID = caseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: caseID,
                    cases: cases,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions,
                    existingPayload: payload
                )
            } else {
                let preferredCaseID = defaultCaseID ?? cases.first?.id
                selectedEnumCaseID = preferredCaseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: preferredCaseID,
                    cases: cases,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions,
                    existingPayload: nil
                )
            }
        }
    }

    var valueSource: TransitionTargetStateValueSource {
        switch selectedChoice {
        case .targetDefault:
            return .targetDefault
        case .sourceStateProperty(let reference):
            return .sourceStateProperty(reference: reference)
        case .eventProperty(let reference):
            return .eventProperty(reference: reference)
        case .literal:
            guard case .primitive(let primitiveType) = targetSchema else {
                return .targetDefault
            }

            return .literal(
                literalDraft.literalValue(for: primitiveType) ?? Self.fallbackLiteralValue(for: primitiveType)
            )
        case .custom:
            return .custom(comment: customCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines))
        case .mapFields:
            return .fieldMap(
                fields: fieldDrafts.map { fieldDraft in
                    TransitionTargetStateFieldAssignment(
                        fieldID: fieldDraft.field.id,
                        valueSource: fieldDraft.valueDraft.valueSource
                    )
                }
            )
        case .explicitEnumCase:
            return .enumCase(
                caseID: selectedEnumCaseID ?? "",
                payload: payloadDrafts.first?.valueDraft.valueSource
            )
        }
    }

    func validationMessage(propertyName: String) -> String? {
        switch selectedChoice {
        case .literal:
            guard case .primitive(let primitiveType) = targetSchema else {
                return "Property '\(propertyName)' cannot use a literal value."
            }

            return literalDraft.validationMessage(
                for: primitiveType,
                propertyName: propertyName
            )

        case .custom:
            let trimmedComment = customCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedComment.isEmpty ? "Property '\(propertyName)' needs a custom note." : nil

        case .mapFields:
            return fieldDrafts.compactMap { fieldDraft in
                fieldDraft.valueDraft.validationMessage(propertyName: fieldDraft.field.name)
            }.first

        case .explicitEnumCase:
            guard let selectedEnumCaseID,
                  !selectedEnumCaseID.isEmpty else {
                return "Property '\(propertyName)' needs a selected enum case."
            }

            return payloadDrafts.first?.valueDraft.validationMessage(propertyName: propertyName)

        default:
            return nil
        }
    }

    mutating func selectEnumCase(
        _ caseID: String,
        cases: [ResolvedEnumCase],
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption]
    ) {
        selectedEnumCaseID = caseID
        let existingPayload = payloadDrafts.first?.valueDraft.valueSource
        payloadDrafts = Self.payloadDrafts(
            caseID: caseID,
            cases: cases,
            sourceOptions: sourceOptions,
            eventOptions: eventOptions,
            existingPayload: existingPayload
        )
    }

    nonisolated private static func choice(
        for valueSource: TransitionTargetStateValueSource
    ) -> TransitionValueChoice? {
        switch valueSource {
        case .targetDefault:
            return .targetDefault
        case .sourceStateProperty(let reference):
            return .sourceStateProperty(reference)
        case .eventProperty(let reference):
            return .eventProperty(reference)
        case .literal:
            return .literal
        case .custom:
            return .custom
        case .fieldMap:
            return .mapFields
        case .enumCase:
            return .explicitEnumCase
        }
    }

    private static func suggestedChoice(
        for targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption]
    ) -> TransitionValueChoice {
        switch targetSchema {
        case .primitive:
            if let sourceMatch = sourceOptions.first(where: {
                $0.leafName == targetName && $0.valueType == targetType
            }) {
                return .sourceStateProperty(sourceMatch.reference)
            }

            if let eventMatch = eventOptions.first(where: {
                $0.leafName == targetName && $0.valueType == targetType
            }) {
                return .eventProperty(eventMatch.reference)
            }

            return .targetDefault

        case .structType:
            return .mapFields

        case .enumType:
            if let sourceMatch = sourceOptions.first(where: {
                $0.reference.path.isEmpty && $0.leafName == targetName && $0.valueType == targetType
            }) {
                return .sourceStateProperty(sourceMatch.reference)
            }

            if let eventMatch = eventOptions.first(where: {
                $0.reference.path.isEmpty && $0.leafName == targetName && $0.valueType == targetType
            }) {
                return .eventProperty(eventMatch.reference)
            }

            return .explicitEnumCase
        }
    }

    private static func defaultLiteralDraft(
        for targetSchema: ResolvedPropertySchema
    ) -> PropertyDefaultValueDraft {
        guard case .primitive(let primitiveType) = targetSchema else {
            return .init()
        }

        return PropertyDefaultValueDraft(
            defaultValue: fallbackLiteralValue(for: primitiveType)
        )
    }

    private static func fallbackLiteralValue(for type: PropertyType) -> LiteralValue {
        switch type {
        case .string:
            return .string("")
        case .integer:
            return .integer(0)
        case .double:
            return .double(0)
        case .boolean:
            return .boolean(false)
        case .model:
            return .string("")
        }
    }

    private static func payloadDrafts(
        caseID: String?,
        cases: [ResolvedEnumCase],
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption],
        existingPayload: TransitionTargetStateValueSource?
    ) -> [TransitionPayloadDraft] {
        guard let caseID,
              let resolvedCase = cases.first(where: { $0.id == caseID }),
              let payloadSchema = resolvedCase.payloadSchema else {
            return []
        }

        return [
            TransitionPayloadDraft(
                valueDraft: TransitionValueDraft(
                    targetName: resolvedCase.name,
                    targetType: resolvedCase.payloadType ?? .string,
                    targetSchema: payloadSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions,
                    existingValueSource: existingPayload
                )
            )
        ]
    }
}

enum TransitionValueChoice: Hashable, Identifiable {
    case targetDefault
    case sourceStateProperty(PropertyValueReference)
    case eventProperty(PropertyValueReference)
    case literal
    case custom
    case mapFields
    case explicitEnumCase

    var id: String {
        switch self {
        case .targetDefault:
            return "target-default"
        case .sourceStateProperty(let reference):
            return "source-\(reference.propertyID)-\(reference.path.joined(separator: "."))"
        case .eventProperty(let reference):
            return "event-\(reference.propertyID)-\(reference.path.joined(separator: "."))"
        case .literal:
            return "literal"
        case .custom:
            return "custom"
        case .mapFields:
            return "map-fields"
        case .explicitEnumCase:
            return "explicit-enum-case"
        }
    }
}

private struct TransitionValueDraftRowView: View {
    let title: String
    let subtitle: String
    @Binding var draft: TransitionValueDraft
    let sourceStateName: String
    let sourceOptions: [PropertyReferenceOption]
    let eventName: String
    let eventOptions: [PropertyReferenceOption]
    let typeDefinitions: [PayloadTypeDefinition]
    var depth: Int = 0

    private var availableChoices: [TransitionValueChoice] {
        let sourceChoices = sourceOptions
            .filter { $0.valueType == draft.targetType }
            .map { TransitionValueChoice.sourceStateProperty($0.reference) }
        let eventChoices = eventOptions
            .filter { $0.valueType == draft.targetType }
            .map { TransitionValueChoice.eventProperty($0.reference) }

        var choices: [TransitionValueChoice] = [.targetDefault] + sourceChoices + eventChoices

        switch draft.targetSchema {
        case .primitive:
            choices += [.literal, .custom]
        case .structType:
            choices += [.mapFields, .custom]
        case .enumType:
            choices += [.explicitEnumCase, .custom]
        }

        return choices
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            EditorPropertyControlColumn(title: "Fill From") {
                Picker(
                    "Fill From",
                    selection: $draft.selectedChoice
                ) {
                    ForEach(availableChoices) { choice in
                        Text(
                            choice.label(
                                sourceStateName: sourceStateName,
                                sourceOptions: sourceOptions,
                                eventName: eventName,
                                eventOptions: eventOptions
                            )
                        )
                        .tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            switch draft.selectedChoice {
            case .literal:
                if case .primitive(let primitiveType) = draft.targetSchema {
                    LiteralValueInputEditor(
                        type: primitiveType,
                        draft: $draft.literalDraft
                    )
                }

            case .custom:
                CustomNoteInputEditor(
                    propertyName: title,
                    comment: $draft.customCommentDraft
                )

            case .mapFields:
                fieldEditors

            case .explicitEnumCase:
                enumCaseEditor

            default:
                EmptyView()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(depth == 0 ? 0.04 : 0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .padding(.leading, depth == 0 ? 0 : 14)
    }

    @ViewBuilder
    private var fieldEditors: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($draft.fieldDrafts) { $fieldDraft in
                TransitionValueDraftRowView(
                    title: fieldDraft.field.name,
                    subtitle: fieldDraft.field.fieldLabel(typeDefinitions: typeDefinitions),
                    draft: $fieldDraft.valueDraft,
                    sourceStateName: sourceStateName,
                    sourceOptions: sourceOptions,
                    eventName: eventName,
                    eventOptions: eventOptions,
                    typeDefinitions: typeDefinitions,
                    depth: depth + 1
                )
            }
        }
    }

    @ViewBuilder
    private var enumCaseEditor: some View {
        if case .enumType(let cases, _) = draft.targetSchema {
            VStack(alignment: .leading, spacing: 10) {
                EditorPropertyControlColumn(title: "Case") {
                    Picker(
                        "Case",
                        selection: Binding(
                            get: { draft.selectedEnumCaseID ?? cases.first?.id ?? "" },
                            set: { newCaseID in
                                draft.selectEnumCase(
                                    newCaseID,
                                    cases: cases,
                                    sourceOptions: sourceOptions,
                                    eventOptions: eventOptions
                                )
                            }
                        )
                    ) {
                        ForEach(cases) { payloadCase in
                            Text(payloadCase.name)
                                .tag(payloadCase.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if let payloadDraft = draft.payloadDrafts.first {
                    TransitionValueDraftRowView(
                        title: "Payload",
                        subtitle: payloadDraft.valueDraft.payloadLabel(typeDefinitions: typeDefinitions),
                        draft: Binding(
                            get: { draft.payloadDrafts.first?.valueDraft ?? payloadDraft.valueDraft },
                            set: { updatedDraft in
                                draft.payloadDrafts = [TransitionPayloadDraft(valueDraft: updatedDraft)]
                            }
                        ),
                        sourceStateName: sourceStateName,
                        sourceOptions: sourceOptions,
                        eventName: eventName,
                        eventOptions: eventOptions,
                        typeDefinitions: typeDefinitions,
                        depth: depth + 1
                    )
                }
            }
        }
    }
}

private struct LiteralValueInputEditor: View {
    let type: PropertyType
    @Binding var draft: PropertyDefaultValueDraft

    var body: some View {
        EditorPropertyControlColumn(title: "Literal") {
            inputField
        }
        .onAppear {
            draft.isEnabled = true
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch type {
        case .string:
            TextField("Literal string", text: $draft.stringValue, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
        case .integer:
            TextField("Literal integer", text: $draft.integerValue)
                .textFieldStyle(.roundedBorder)
        case .double:
            TextField("Literal double", text: $draft.doubleValue)
                .textFieldStyle(.roundedBorder)
        case .boolean:
            Picker("Literal boolean", selection: $draft.booleanValue) {
                Text("False")
                    .tag(false)
                Text("True")
                    .tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 200, alignment: .leading)
        case .model:
            EmptyView()
        }
    }
}

private struct CustomNoteInputEditor: View {
    let propertyName: String
    @Binding var comment: String

    var body: some View {
        EditorPropertyControlColumn(title: "Custom Note") {
            TextField(
                "Describe how \(propertyName) is assigned",
                text: $comment,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)
        }
    }
}

private extension TransitionValueChoice {
    func label(
        sourceStateName: String,
        sourceOptions: [PropertyReferenceOption],
        eventName: String,
        eventOptions: [PropertyReferenceOption]
    ) -> String {
        switch self {
        case .targetDefault:
            return "Target default"
        case .sourceStateProperty(let reference):
            let label = sourceOptions.first(where: { $0.reference == reference })?.pathNames.joined(separator: ".")
                ?? reference.path.joined(separator: ".")
            return "\(sourceStateName).\(label)"
        case .eventProperty(let reference):
            let label = eventOptions.first(where: { $0.reference == reference })?.pathNames.joined(separator: ".")
                ?? reference.path.joined(separator: ".")
            return "\(eventName).\(label)"
        case .literal:
            return "Literal value"
        case .custom:
            return "Custom note"
        case .mapFields:
            return "Map fields"
        case .explicitEnumCase:
            return "Set explicit case"
        }
    }
}

private extension ResolvedPropertyField {
    func fieldLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        let property = PropertyDefinition(
            id: id,
            name: name,
            type: type
        )

        return property.editorLabel(typeDefinitions: typeDefinitions)
    }
}

private extension TransitionValueDraft {
    func payloadLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
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
