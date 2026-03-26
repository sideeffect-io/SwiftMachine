//
//  StateMachineDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct ReusableStatePropertyOption: Identifiable, Hashable {
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: PropertyDefaultValue?
    let sources: [String]

    nonisolated var id: String {
        [
            name,
            type.rawValue,
            isOptional ? "optional" : "required",
            defaultValue?.signatureFragment ?? "no-default"
        ].joined(separator: "|")
    }

    nonisolated func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        propertyDefinition.editorLabel(typeDefinitions: typeDefinitions)
    }

    nonisolated var sourceSummary: String {
        "From " + sources.joined(separator: ", ")
    }

    nonisolated var propertyDefinition: PropertyDefinition {
        PropertyDefinition(
            name: name,
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }
}

private struct ReusableStatePropertySignature: Hashable {
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: PropertyDefaultValue?
}

struct StateMachineDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let initialStateID: String
    let types: [PayloadTypeDefinition]
    let states: [StateDefinition]
    let events: [EventDefinition]
    let transitions: [TransitionDefinition]

    nonisolated init(
        id: String = UUID().uuidString,
        name: String,
        initialStateID: String,
        types: [PayloadTypeDefinition] = [],
        states: [StateDefinition],
        events: [EventDefinition],
        transitions: [TransitionDefinition]
    ) {
        self.id = id
        self.name = name
        self.initialStateID = initialStateID
        self.types = types
        self.states = states
        self.events = events
        self.transitions = transitions
    }

    nonisolated var isValid: Bool {
        validate().isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case initialStateID
        case types
        case states
        case events
        case transitions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        initialStateID = try container.decode(String.self, forKey: .initialStateID)
        types = try container.decodeIfPresent([PayloadTypeDefinition].self, forKey: .types) ?? []
        states = try container.decode([StateDefinition].self, forKey: .states)
        events = try container.decode([EventDefinition].self, forKey: .events)
        transitions = try container.decode([TransitionDefinition].self, forKey: .transitions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(initialStateID, forKey: .initialStateID)
        try container.encode(types, forKey: .types)
        try container.encode(states, forKey: .states)
        try container.encode(events, forKey: .events)
        try container.encode(transitions, forKey: .transitions)
    }
}

extension StateMachineDefinition {
    nonisolated var reusableStatePropertyOptions: [ReusableStatePropertyOption] {
        var propertySources: [ReusableStatePropertySignature: Set<String>] = [:]

        for state in states {
            for property in state.properties {
                let signature = ReusableStatePropertySignature(
                    name: property.name,
                    type: property.type,
                    isOptional: property.isOptional,
                    defaultValue: property.defaultValue
                )
                propertySources[signature, default: []].insert("state \(state.name)")
            }
        }

        for event in events {
            for property in event.properties {
                let signature = ReusableStatePropertySignature(
                    name: property.name,
                    type: property.type,
                    isOptional: property.isOptional,
                    defaultValue: property.defaultValue
                )
                propertySources[signature, default: []].insert("event \(event.name)")
            }
        }

        return propertySources
            .map { signature, sources in
                ReusableStatePropertyOption(
                    name: signature.name,
                    type: signature.type,
                    isOptional: signature.isOptional,
                    defaultValue: signature.defaultValue,
                    sources: sources.sorted()
                )
            }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    if lhs.type == rhs.type {
                        return !lhs.isOptional && rhs.isOptional
                    }

                    return lhs.type.rawValue < rhs.type.rawValue
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    nonisolated func typeIsReferenced(_ typeID: String) -> Bool {
        states.contains { state in
            state.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }
        || events.contains { event in
            event.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }
        || types.contains { type in
            switch type.kind {
            case .structType(let fields):
                return fields.contains(where: { $0.type.referencedTypeID == typeID })
            case .enumType(let cases, _):
                return cases.contains(where: { $0.payloadType?.referencedTypeID == typeID })
            }
        }
    }
}
