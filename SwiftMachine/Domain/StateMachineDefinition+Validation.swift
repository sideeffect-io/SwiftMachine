//
//  StateMachineDefinition+Validation.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

extension StateMachineDefinition {
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        func orderedDuplicates(in values: [String]) -> [String] {
            var seen = Set<String>()
            var duplicates = Set<String>()
            var orderedDuplicates: [String] = []

            for value in values {
                if !seen.insert(value).inserted && duplicates.insert(value).inserted {
                    orderedDuplicates.append(value)
                }
            }

            return orderedDuplicates
        }

        let stateIDs = orderedDuplicates(in: states.map(\.id))
        let stateNames = orderedDuplicates(in: states.map(\.name))
        let eventIDs = orderedDuplicates(in: events.map(\.id))
        let eventNames = orderedDuplicates(in: events.map(\.name))
        let knownStateIDs = Set(states.map(\.id))
        let knownEventIDs = Set(events.map(\.id))

        for state in states {
            if state.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStateID(stateName: state.name))
            }

            if state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStateName(stateID: state.id))
            }

            for duplicateName in orderedDuplicates(in: state.properties.map(\.name)) {
                errors.append(.duplicateStatePropertyName(stateID: state.id, propertyName: duplicateName))
            }
        }

        for duplicateID in stateIDs {
            errors.append(.duplicateStateID(duplicateID))
        }

        for duplicateName in stateNames {
            errors.append(.duplicateStateName(duplicateName))
        }

        for event in events {
            if event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyEventID(eventName: event.name))
            }

            if event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyEventName(eventID: event.id))
            }

            for duplicateName in orderedDuplicates(in: event.properties.map(\.name)) {
                errors.append(.duplicateEventPropertyName(eventID: event.id, propertyName: duplicateName))
            }
        }

        for duplicateID in eventIDs {
            errors.append(.duplicateEventID(duplicateID))
        }

        for duplicateName in eventNames {
            errors.append(.duplicateEventName(duplicateName))
        }

        if !knownStateIDs.contains(initialStateID) {
            errors.append(.unknownInitialState(initialStateID))
        }

        for transition in transitions {
            if !knownStateIDs.contains(transition.sourceStateID) {
                errors.append(.unknownTransitionSourceState(
                    transitionID: transition.id,
                    stateID: transition.sourceStateID
                ))
            }

            if !knownStateIDs.contains(transition.targetStateID) {
                errors.append(.unknownTransitionTargetState(
                    transitionID: transition.id,
                    stateID: transition.targetStateID
                ))
            }

            if !knownEventIDs.contains(transition.eventID) {
                errors.append(.unknownTransitionEvent(
                    transitionID: transition.id,
                    eventID: transition.eventID
                ))
            }
        }

        return errors
    }

    enum ValidationError: Error, Sendable, Equatable, Hashable {
        case emptyStateID(stateName: String)
        case emptyStateName(stateID: String)
        case duplicateStateID(String)
        case duplicateStateName(String)
        case emptyEventID(eventName: String)
        case emptyEventName(eventID: String)
        case duplicateEventID(String)
        case duplicateEventName(String)
        case duplicateStatePropertyName(stateID: String, propertyName: String)
        case duplicateEventPropertyName(eventID: String, propertyName: String)
        case unknownInitialState(String)
        case unknownTransitionSourceState(transitionID: String, stateID: String)
        case unknownTransitionTargetState(transitionID: String, stateID: String)
        case unknownTransitionEvent(transitionID: String, eventID: String)
    }
}
