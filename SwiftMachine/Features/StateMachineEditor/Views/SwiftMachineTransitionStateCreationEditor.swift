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
        targetProperties: [PropertyDefinition]
    ) {
        propertyDrafts = targetProperties.map { targetProperty in
            TransitionTargetStatePropertyDraft(
                targetProperty: targetProperty,
                existingAssignment: existingCreation.assignments.first(where: {
                    $0.targetPropertyID == targetProperty.id
                }),
                sourceProperties: sourceProperties,
                eventProperties: eventProperties
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
    @Binding var draft: TransitionTargetStateCreationDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create \(targetStateName) by deciding how each target property is filled from the source state, the event, or a literal value.")
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
                        TransitionTargetStatePropertyDraftRowView(
                            propertyDraft: $propertyDraft,
                            sourceStateName: sourceStateName,
                            sourceProperties: sourceProperties,
                            eventName: eventName,
                            eventProperties: eventProperties
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
    var selectedValueChoice: TransitionTargetStateValueChoice
    var literalDraft: PropertyDefaultValueDraft

    var id: String {
        targetProperty.id
    }

    init(
        targetProperty: PropertyDefinition,
        existingAssignment: TransitionTargetStatePropertyAssignment?,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition]
    ) {
        let availableChoices = Self.availableChoices(
            for: targetProperty,
            sourceProperties: sourceProperties,
            eventProperties: eventProperties
        )
        let suggestedChoice = Self.suggestedChoice(
            for: targetProperty,
            sourceProperties: sourceProperties,
            eventProperties: eventProperties
        )
        let selectedValueChoice = existingAssignment
            .flatMap { assignment in
                Self.choice(
                    for: assignment,
                    targetProperty: targetProperty,
                    availableChoices: availableChoices
                )
            } ?? suggestedChoice

        self.targetProperty = targetProperty
        self.selectedValueChoice = selectedValueChoice

        switch existingAssignment?.valueSource {
        case .literal(let literalValue):
            literalDraft = PropertyDefaultValueDraft(defaultValue: literalValue)
        default:
            literalDraft = PropertyDefaultValueDraft(defaultValue: targetProperty.defaultValue)
            literalDraft.isEnabled = true
        }
    }

    var assignment: TransitionTargetStatePropertyAssignment {
        TransitionTargetStatePropertyAssignment(
            targetPropertyID: targetProperty.id,
            valueSource: valueSource
        )
    }

    var validationMessage: String? {
        guard selectedValueChoice == .literal else {
            return nil
        }

        return literalDraft.validationMessage(
            for: targetProperty.type,
            propertyName: targetProperty.name
        )
    }

    private var valueSource: TransitionTargetStateValueSource {
        switch selectedValueChoice {
        case .targetDefault:
            return .targetDefault
        case .sourceStateProperty(let propertyID):
            return .sourceStateProperty(propertyID: propertyID)
        case .eventProperty(let propertyID):
            return .eventProperty(propertyID: propertyID)
        case .literal:
            return .literal(literalDraft.literalValue(for: targetProperty.type) ?? fallbackLiteralValue)
        }
    }

    private var fallbackLiteralValue: LiteralValue {
        switch targetProperty.type {
        case .string:
            return .string("")
        case .integer:
            return .integer(0)
        case .double:
            return .double(0)
        case .boolean:
            return .boolean(false)
        }
    }

    private static func choice(
        for assignment: TransitionTargetStatePropertyAssignment,
        targetProperty: PropertyDefinition,
        availableChoices: [TransitionTargetStateValueChoice]
    ) -> TransitionTargetStateValueChoice? {
        guard assignment.targetPropertyID == targetProperty.id else {
            return nil
        }

        let choice: TransitionTargetStateValueChoice
        switch assignment.valueSource {
        case .targetDefault:
            choice = .targetDefault
        case .sourceStateProperty(let propertyID):
            choice = .sourceStateProperty(propertyID)
        case .eventProperty(let propertyID):
            choice = .eventProperty(propertyID)
        case .literal:
            choice = .literal
        }

        return availableChoices.contains(choice) ? choice : nil
    }

    private static func suggestedChoice(
        for targetProperty: PropertyDefinition,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition]
    ) -> TransitionTargetStateValueChoice {
        if let sourceProperty = sourceProperties.first(where: {
            $0.name == targetProperty.name && $0.type == targetProperty.type
        }) {
            return .sourceStateProperty(sourceProperty.id)
        }

        if let eventProperty = eventProperties.first(where: {
            $0.name == targetProperty.name && $0.type == targetProperty.type
        }) {
            return .eventProperty(eventProperty.id)
        }

        return .targetDefault
    }

    static func availableChoices(
        for targetProperty: PropertyDefinition,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition]
    ) -> [TransitionTargetStateValueChoice] {
        let sourceChoices = sourceProperties
            .filter { $0.type == targetProperty.type }
            .map { TransitionTargetStateValueChoice.sourceStateProperty($0.id) }
        let eventChoices = eventProperties
            .filter { $0.type == targetProperty.type }
            .map { TransitionTargetStateValueChoice.eventProperty($0.id) }

        return [.targetDefault] + sourceChoices + eventChoices + [.literal]
    }
}

enum TransitionTargetStateValueChoice: Hashable, Identifiable {
    case targetDefault
    case sourceStateProperty(String)
    case eventProperty(String)
    case literal

    var id: String {
        switch self {
        case .targetDefault:
            return "target-default"
        case .sourceStateProperty(let propertyID):
            return "source-\(propertyID)"
        case .eventProperty(let propertyID):
            return "event-\(propertyID)"
        case .literal:
            return "literal"
        }
    }
}

private struct TransitionTargetStatePropertyDraftRowView: View {
    @Binding var propertyDraft: TransitionTargetStatePropertyDraft

    let sourceStateName: String
    let sourceProperties: [PropertyDefinition]
    let eventName: String
    let eventProperties: [PropertyDefinition]

    private var availableChoices: [TransitionTargetStateValueChoice] {
        TransitionTargetStatePropertyDraft.availableChoices(
            for: propertyDraft.targetProperty,
            sourceProperties: sourceProperties,
            eventProperties: eventProperties
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(propertyDraft.targetProperty.name)
                    .font(.subheadline.weight(.semibold))

                Text(propertyDraft.targetProperty.editorLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            EditorPropertyControlColumn(title: "Fill From") {
                Picker(
                    "Fill From",
                    selection: $propertyDraft.selectedValueChoice
                ) {
                    ForEach(availableChoices) { choice in
                        Text(
                            choice.label(
                                sourceStateName: sourceStateName,
                                sourceProperties: sourceProperties,
                                eventName: eventName,
                                eventProperties: eventProperties
                            )
                        )
                        .tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            if propertyDraft.selectedValueChoice == .literal {
                LiteralValueInputEditor(
                    type: propertyDraft.targetProperty.type,
                    draft: $propertyDraft.literalDraft
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
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
        }
    }
}

private extension TransitionTargetStateValueChoice {
    func label(
        sourceStateName: String,
        sourceProperties: [PropertyDefinition],
        eventName: String,
        eventProperties: [PropertyDefinition]
    ) -> String {
        switch self {
        case .targetDefault:
            return "Target default"
        case .sourceStateProperty(let propertyID):
            let propertyName = sourceProperties.first(where: { $0.id == propertyID })?.name ?? propertyID
            return "\(sourceStateName).\(propertyName)"
        case .eventProperty(let propertyID):
            let propertyName = eventProperties.first(where: { $0.id == propertyID })?.name ?? propertyID
            return "\(eventName).\(propertyName)"
        case .literal:
            return "Literal value"
        }
    }
}
