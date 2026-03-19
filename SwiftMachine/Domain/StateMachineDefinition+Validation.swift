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
        let statePropertiesByStateID = states.reduce(into: [String: [String: PropertyDefinition]]()) { partialResult, state in
            guard partialResult[state.id] == nil else {
                return
            }

            partialResult[state.id] = state.properties.reduce(into: [String: PropertyDefinition]()) { propertyMap, property in
                guard propertyMap[property.id] == nil else {
                    return
                }

                propertyMap[property.id] = property
            }
        }
        let eventPropertiesByEventID = events.reduce(into: [String: [String: PropertyDefinition]]()) { partialResult, event in
            guard partialResult[event.id] == nil else {
                return
            }

            partialResult[event.id] = event.properties.reduce(into: [String: PropertyDefinition]()) { propertyMap, property in
                guard propertyMap[property.id] == nil else {
                    return
                }

                propertyMap[property.id] = property
            }
        }

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

            for duplicateTargetPropertyID in orderedDuplicates(
                in: transition.targetStateCreation.assignments.map(\.targetPropertyID)
            ) {
                errors.append(
                    .duplicateTransitionTargetPropertyAssignment(
                        transitionID: transition.id,
                        propertyID: duplicateTargetPropertyID
                    )
                )
            }

            guard let targetProperties = statePropertiesByStateID[transition.targetStateID] else {
                continue
            }

            let sourceProperties = statePropertiesByStateID[transition.sourceStateID]
            let eventProperties = eventPropertiesByEventID[transition.eventID]

            for assignment in transition.targetStateCreation.assignments {
                guard let targetProperty = targetProperties[assignment.targetPropertyID] else {
                    errors.append(
                        .unknownTransitionTargetProperty(
                            transitionID: transition.id,
                            stateID: transition.targetStateID,
                            propertyID: assignment.targetPropertyID
                        )
                    )
                    continue
                }

                switch assignment.valueSource {
                case .targetDefault:
                    break

                case .sourceStateProperty(let propertyID):
                    guard let sourceProperties,
                          let sourceProperty = sourceProperties[propertyID] else {
                        if sourceProperties != nil {
                            errors.append(
                                .unknownTransitionSourceProperty(
                                    transitionID: transition.id,
                                    stateID: transition.sourceStateID,
                                    propertyID: propertyID
                                )
                            )
                        }
                        continue
                    }

                    if sourceProperty.type != targetProperty.type {
                        errors.append(
                            .incompatibleTransitionTargetPropertyAssignment(
                                transitionID: transition.id,
                                targetPropertyID: targetProperty.id
                            )
                        )
                    }

                case .eventProperty(let propertyID):
                    guard let eventProperties,
                          let eventProperty = eventProperties[propertyID] else {
                        if eventProperties != nil {
                            errors.append(
                                .unknownTransitionEventProperty(
                                    transitionID: transition.id,
                                    eventID: transition.eventID,
                                    propertyID: propertyID
                                )
                            )
                        }
                        continue
                    }

                    if eventProperty.type != targetProperty.type {
                        errors.append(
                            .incompatibleTransitionTargetPropertyAssignment(
                                transitionID: transition.id,
                                targetPropertyID: targetProperty.id
                            )
                        )
                    }

                case .literal(let literalValue):
                    if literalValue.type != targetProperty.type {
                        errors.append(
                            .incompatibleTransitionTargetPropertyAssignment(
                                transitionID: transition.id,
                                targetPropertyID: targetProperty.id
                            )
                        )
                    }
                }
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
        case duplicateTransitionTargetPropertyAssignment(transitionID: String, propertyID: String)
        case unknownTransitionTargetProperty(transitionID: String, stateID: String, propertyID: String)
        case unknownTransitionSourceProperty(transitionID: String, stateID: String, propertyID: String)
        case unknownTransitionEventProperty(transitionID: String, eventID: String, propertyID: String)
        case incompatibleTransitionTargetPropertyAssignment(transitionID: String, targetPropertyID: String)
    }
}
