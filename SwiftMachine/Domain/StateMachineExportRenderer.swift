//
//  StateMachineExportRenderer.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import Foundation

struct RenderedStateMachineExport: Sendable, Equatable {
    let revision: UInt64
    let machineName: String
    let suggestedFilename: String
    let markdown: String
}

struct StateMachineExportRenderer: Sendable {
    nonisolated init() {}

    nonisolated
    func render(
        definition: StateMachineDefinition,
        revision: UInt64
    ) -> RenderedStateMachineExport {
        let context = StateMachineExportContext(definition: definition)
        let markdown = context.renderMarkdown()

        return RenderedStateMachineExport(
            revision: revision,
            machineName: definition.name,
            suggestedFilename: context.suggestedFilename,
            markdown: markdown
        )
    }
}

private struct StateMachineExportContext: Sendable {
    let definition: StateMachineDefinition

    nonisolated
    var suggestedFilename: String {
        "\(sanitizedMachineName).state-machine.md"
    }

    nonisolated
    func renderMarkdown() -> String {
        let sections = [
            renderMachineSection(),
            renderTypesSection(),
            renderStatesSection(),
            renderEventsSection(),
            renderTransitionsSection()
        ]

        return (["# State Machine: \(definition.name)"] + sections)
            .joined(separator: "\n\n")
            + "\n"
    }

    nonisolated
    private var sanitizedMachineName: String {
        let collapsedWhitespace = definition.name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsedWhitespace.isEmpty ? "StateMachine" : collapsedWhitespace
    }

    nonisolated
    private func renderMachineSection() -> String {
        let initialStateName = definition.states.first(where: { $0.id == definition.initialStateID })?.name
            ?? "unknown"

        return section(
            title: "Machine",
            lines: [
                "- initial_state: \(initialStateName)"
            ]
        )
    }

    nonisolated
    private func renderTypesSection() -> String {
        section(
            title: "Types",
            lines: definition.types.map(renderType)
        )
    }

    nonisolated
    private func renderStatesSection() -> String {
        section(
            title: "States",
            lines: definition.states.map(renderState)
        )
    }

    nonisolated
    private func renderEventsSection() -> String {
        section(
            title: "Events",
            lines: definition.events.map(renderEvent)
        )
    }

    nonisolated
    private func renderTransitionsSection() -> String {
        section(
            title: "Transitions",
            lines: definition.transitions.map(renderTransition)
        )
    }

    nonisolated
    private func section(
        title: String,
        lines: [String]
    ) -> String {
        let body = lines.isEmpty ? ["- none"] : lines
        return (["## \(title)"] + body).joined(separator: "\n")
    }

    nonisolated
    private func renderType(_ type: PayloadTypeDefinition) -> String {
        switch type.kind {
        case .structType(let fields):
            return "- \(type.name) = struct\(renderPropertyBlock(fields))"

        case .enumType(let cases, let defaultCaseID):
            let renderedCases = cases.map { payloadCase in
                renderEnumCase(payloadCase, defaultCaseID: defaultCaseID)
            }
            .joined(separator: ", ")

            return "- \(type.name) = enum { \(renderedCases) }"
        }
    }

    nonisolated
    private func renderState(_ state: StateDefinition) -> String {
        "- \(state.name)\(renderPropertyBlock(state.properties))"
    }

    nonisolated
    private func renderEvent(_ event: EventDefinition) -> String {
        "- \(event.name)\(renderPropertyBlock(event.properties))"
    }

    nonisolated
    private func renderTransition(_ transition: TransitionDefinition) -> String {
        let sourceState = definition.states.first(where: { $0.id == transition.sourceStateID })
        let event = definition.events.first(where: { $0.id == transition.eventID })
        let targetState = definition.states.first(where: { $0.id == transition.targetStateID })

        let header = [
            sourceState?.name ?? "unknown-state",
            "--",
            event?.name ?? "unknown-event",
            "->",
            targetState?.name ?? "unknown-state"
        ]
        .joined(separator: " ")

        var fragments: [String] = []

        if let targetState {
            let assignmentLines = transition.targetStateCreation.assignments.compactMap { assignment in
                renderAssignment(
                    assignment,
                    targetProperties: targetState.properties,
                    sourceProperties: sourceState?.properties ?? [],
                    eventProperties: event?.properties ?? []
                )
            }

            if !assignmentLines.isEmpty {
                fragments.append("assign { \(assignmentLines.joined(separator: ", ")) }")
            }
        }

        if let guardReference = transition.guard {
            fragments.append("guard \(renderReference(name: guardReference.name, description: guardReference.description))")
        }

        if !transition.effects.isEmpty {
            let renderedEffects = transition.effects.map {
                renderReference(name: $0.name, description: $0.description)
            }
            .joined(separator: ", ")

            fragments.append("effects [\(renderedEffects)]")
        }

        guard !fragments.isEmpty else {
            return "- \(header)"
        }

        return "- \(header); \(fragments.joined(separator: "; "))"
    }

    nonisolated
    private func renderAssignment(
        _ assignment: TransitionTargetStatePropertyAssignment,
        targetProperties: [PropertyDefinition],
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition]
    ) -> String? {
        guard let targetProperty = targetProperties.first(where: { $0.id == assignment.targetPropertyID }),
              let targetSchema = definition.schema(for: targetProperty) else {
            return nil
        }

        return "\(targetProperty.name) <- \(renderValueSource(assignment.valueSource, expectedSchema: targetSchema, sourceProperties: sourceProperties, eventProperties: eventProperties))"
    }

    nonisolated
    private func renderValueSource(
        _ valueSource: TransitionTargetStateValueSource,
        expectedSchema: ResolvedPropertySchema,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition]
    ) -> String {
        switch valueSource {
        case .targetDefault:
            return "default"

        case .sourceStateProperty(let reference):
            let label = propertyPathLabel(reference: reference, in: sourceProperties) ?? "unknown"
            return "source.\(label)"

        case .eventProperty(let reference):
            let label = propertyPathLabel(reference: reference, in: eventProperties) ?? "unknown"
            return "event.\(label)"

        case .literal(let literal):
            return renderLiteral(literal)

        case .custom(let comment):
            return "custom(\(String(reflecting: normalizedText(comment))))"

        case .fieldMap(let fields):
            let renderedFields: [String] = fields.compactMap { field -> String? in
                guard case .structType(let resolvedFields) = expectedSchema,
                      let resolvedField = resolvedFields.first(where: { $0.id == field.fieldID }) else {
                    return nil
                }

                return "\(resolvedField.name) <- \(renderValueSource(field.valueSource, expectedSchema: resolvedField.schema, sourceProperties: sourceProperties, eventProperties: eventProperties))"
            }

            return "{ \(renderedFields.joined(separator: ", ")) }"

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = expectedSchema else {
                return ".unknown"
            }

            let resolvedCase = cases.first(where: { $0.id == caseID })
            let caseName = resolvedCase?.name ?? "unknown"

            guard let payload else {
                return ".\(caseName)"
            }

            let payloadSchema = resolvedCase?.payloadSchema ?? .primitive(type: .string)
            let payloadText = renderValueSource(
                payload,
                expectedSchema: payloadSchema,
                sourceProperties: sourceProperties,
                eventProperties: eventProperties
            )

            return ".\(caseName)(\(payloadText))"
        }
    }

    nonisolated
    private func renderEnumCase(
        _ payloadCase: PayloadEnumCaseDefinition,
        defaultCaseID: String?
    ) -> String {
        var renderedCase = payloadCase.name

        if let payloadType = payloadCase.payloadType {
            renderedCase += "(\(renderTypeLabel(payloadType)))"
        }

        if payloadCase.id == defaultCaseID {
            renderedCase += " [default]"
        }

        return renderedCase
    }

    nonisolated
    private func renderPropertyBlock(_ properties: [PropertyDefinition]) -> String {
        guard !properties.isEmpty else {
            return ""
        }

        let renderedProperties = properties.map(renderProperty).joined(separator: ", ")
        return " { \(renderedProperties) }"
    }

    nonisolated
    private func renderProperty(_ property: PropertyDefinition) -> String {
        var rendered = "\(property.name): \(renderTypeLabel(property.type))"

        if property.isOptional {
            rendered += "?"
        }

        if let defaultValue = property.defaultValue {
            rendered += " = \(renderPropertyDefaultValue(defaultValue, type: property.type))"
        }

        return rendered
    }

    nonisolated
    private func renderTypeLabel(_ type: PropertyType) -> String {
        switch type {
        case .string, .integer, .double, .boolean:
            return type.rawValue
        case .model(let typeID):
            return definition.payloadTypeDefinition(id: typeID)?.name ?? "missing-type"
        }
    }

    nonisolated
    private func renderPropertyDefaultValue(
        _ defaultValue: PropertyDefaultValue,
        type: PropertyType
    ) -> String {
        let propertySchema = definition.schema(for: type)

        switch defaultValue {
        case .string(let value):
            return String(reflecting: value)

        case .integer(let value):
            return String(value)

        case .double(let value):
            return String(value)

        case .boolean(let value):
            return value ? "true" : "false"

        case .structValue(let fields):
            let renderedFields = fields.map { field in
                let fieldName: String
                let fieldType: PropertyType

                if case .structType(let resolvedFields)? = propertySchema,
                   let resolvedField = resolvedFields.first(where: { $0.id == field.fieldID }) {
                    fieldName = resolvedField.name
                    fieldType = resolvedField.type
                } else {
                    fieldName = "field"
                    fieldType = .string
                }

                return "\(fieldName): \(renderPropertyDefaultValue(field.value, type: fieldType))"
            }
            .joined(separator: ", ")

            return "{ \(renderedFields) }"

        case .enumCase(let caseID, let payload):
            let resolvedCase: ResolvedEnumCase?
            if case .enumType(let cases, _)? = propertySchema {
                resolvedCase = cases.first(where: { $0.id == caseID })
            } else {
                resolvedCase = nil
            }

            let caseName = resolvedCase?.name ?? "unknown"

            guard let payload else {
                return ".\(caseName)"
            }

            let payloadType = resolvedCase?.payloadType ?? .string
            return ".\(caseName)(\(renderPropertyDefaultValue(payload, type: payloadType)))"
        }
    }

    nonisolated
    private func renderLiteral(_ literal: LiteralValue) -> String {
        switch literal {
        case .string(let value):
            return String(reflecting: value)
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        }
    }

    nonisolated
    private func renderReference(
        name: String,
        description: String?
    ) -> String {
        guard let description, !normalizedText(description).isEmpty else {
            return name
        }

        return "\(name) (\(String(reflecting: normalizedText(description))))"
    }

    nonisolated
    private func propertyPathLabel(
        reference: PropertyValueReference,
        in properties: [PropertyDefinition]
    ) -> String? {
        guard let property = properties.first(where: { $0.id == reference.propertyID }),
              var currentSchema = definition.schema(for: property) else {
            return nil
        }

        var pathNames = [property.name]

        for componentID in reference.path {
            guard case .structType(let fields) = currentSchema,
                  let field = fields.first(where: { $0.id == componentID }) else {
                return nil
            }

            pathNames.append(field.name)
            currentSchema = field.schema
        }

        return pathNames.joined(separator: ".")
    }

    nonisolated
    private func normalizedText(_ value: String) -> String {
        value
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
