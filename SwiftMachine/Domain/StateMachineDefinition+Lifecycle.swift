//
//  StateMachineDefinition+Editor.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

extension StateMachineDefinition {
    static func makeNew(
        name: String,
        initialStateName: String,
        initialStateProperties: [PropertyDefinition]
    ) -> StateMachineDefinition? {
        let machineName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateName = initialStateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedProperties = initialStateProperties.map(\.normalizedForEditor)

        guard !machineName.isEmpty, !stateName.isEmpty else {
            return nil
        }

        guard normalizedProperties.allSatisfy({ !$0.name.isEmpty }) else {
            return nil
        }

        let propertyNames = normalizedProperties.map(\.name)
        guard Set(propertyNames).count == propertyNames.count else {
            return nil
        }

        let initialState = StateDefinition(
            name: stateName,
            properties: normalizedProperties
        )

        let stateMachine = StateMachineDefinition(
            name: machineName,
            initialStateID: initialState.id,
            states: [initialState],
            events: [],
            transitions: []
        )

        guard stateMachine.isValid else {
            return nil
        }

        return stateMachine
    }

    func addingState() -> StateMachineDefinition {
        let newState = StateDefinition(
            name: Self.nextAvailableName(
                prefix: "State",
                existingNames: states.map(\.name)
            )
        )

        return StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states + [newState],
            events: events,
            transitions: transitions
        )
    }

    func addingEvent() -> StateMachineDefinition {
        let newEvent = EventDefinition(
            name: Self.nextAvailableName(
                prefix: "Event",
                existingNames: events.map(\.name)
            )
        )

        return StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: events + [newEvent],
            transitions: transitions
        )
    }

    private static func nextAvailableName(
        prefix: String,
        existingNames: [String]
    ) -> String {
        let normalizedNames = Set(
            existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )

        var index = 1
        var candidate = "\(prefix) \(index)"

        while normalizedNames.contains(candidate) {
            index += 1
            candidate = "\(prefix) \(index)"
        }

        return candidate
    }
}

private extension PropertyDefinition {
    var normalizedForEditor: PropertyDefinition {
        PropertyDefinition(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }
}
