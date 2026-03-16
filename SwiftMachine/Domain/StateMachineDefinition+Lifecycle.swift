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

    func nextAvailableStateName() -> String {
        Self.nextAvailableName(
            prefix: "State",
            existingNames: states.map(\.name)
        )
    }

    func addingState() -> StateMachineDefinition {
        guard let result = addingState(
            named: nextAvailableStateName(),
            properties: []
        ) else {
            return self
        }

        return result.definition
    }

    func addingState(
        named proposedName: String,
        properties: [PropertyDefinition]
    ) -> (definition: StateMachineDefinition, stateID: String)? {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedProperties = properties.map(\.normalizedForNewState)

        guard !trimmedName.isEmpty else {
            return nil
        }

        guard normalizedProperties.allSatisfy({ !$0.name.isEmpty }) else {
            return nil
        }

        let propertyNames = normalizedProperties.map(\.name)
        guard Set(propertyNames).count == propertyNames.count else {
            return nil
        }

        let newState = StateDefinition(
            name: trimmedName,
            properties: normalizedProperties
        )

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states + [newState],
            events: events,
            transitions: transitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return (definition: updatedDefinition, stateID: newState.id)
    }

    func renamingState(
        id stateID: String,
        to proposedName: String
    ) -> StateMachineDefinition? {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return nil
        }

        var didUpdateState = false
        let updatedStates = states.map { state in
            guard state.id == stateID else {
                return state
            }

            didUpdateState = true

            return StateDefinition(
                id: state.id,
                name: trimmedName,
                properties: state.properties
            )
        }

        guard didUpdateState else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: updatedStates,
            events: events,
            transitions: transitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func updatingProperties(
        _ properties: [PropertyDefinition],
        forStateID stateID: String
    ) -> StateMachineDefinition? {
        let normalizedProperties = properties.map(\.normalizedForEditor)

        guard normalizedProperties.allSatisfy({ !$0.name.isEmpty }) else {
            return nil
        }

        let propertyNames = normalizedProperties.map(\.name)
        guard Set(propertyNames).count == propertyNames.count else {
            return nil
        }

        var didUpdateState = false
        let updatedStates = states.map { state in
            guard state.id == stateID else {
                return state
            }

            didUpdateState = true

            return StateDefinition(
                id: state.id,
                name: state.name,
                properties: normalizedProperties
            )
        }

        guard didUpdateState else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: updatedStates,
            events: events,
            transitions: transitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func addingEvent() -> (definition: StateMachineDefinition, eventID: String)? {
        addingEvent(
            named: Self.nextAvailableName(
                prefix: "Event",
                existingNames: events.map(\.name)
            )
        )
    }

    func addingEvent(named eventName: String) -> (definition: StateMachineDefinition, eventID: String)? {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return nil
        }

        let newEvent = EventDefinition(
            name: trimmedName
        )

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: events + [newEvent],
            transitions: transitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return (definition: updatedDefinition, eventID: newEvent.id)
    }

    func addingTransition(
        sourceStateID: String,
        eventID: String,
        targetStateID: String
    ) -> (definition: StateMachineDefinition, transitionID: String)? {
        let knownStateIDs = Set(states.map(\.id))
        let knownEventIDs = Set(events.map(\.id))

        guard knownStateIDs.contains(sourceStateID),
              knownStateIDs.contains(targetStateID),
              knownEventIDs.contains(eventID) else {
            return nil
        }

        let newTransition = TransitionDefinition(
            sourceStateID: sourceStateID,
            eventID: eventID,
            targetStateID: targetStateID
        )

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: events,
            transitions: transitions + [newTransition]
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return (definition: updatedDefinition, transitionID: newTransition.id)
    }

    func assigningEvent(
        eventID: String,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            eventID: eventID
        )
    }

    func assigningNewEvent(
        named eventName: String,
        toTransitionID transitionID: String
    ) -> (definition: StateMachineDefinition, eventID: String)? {
        guard let eventResult = addingEvent(named: eventName),
              let updatedDefinition = eventResult.definition.assigningEvent(
                eventID: eventResult.eventID,
                toTransitionID: transitionID
              ) else {
            return nil
        }

        return (
            definition: updatedDefinition,
            eventID: eventResult.eventID
        )
    }

    func assigningSourceState(
        stateID: String,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            sourceStateID: stateID
        )
    }

    func assigningTargetState(
        stateID: String,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            targetStateID: stateID
        )
    }

    func assigningGuard(
        _ guardReference: GuardReference,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        let normalizedGuard = guardReference.normalizedForEditor

        guard !normalizedGuard.name.isEmpty else {
            return nil
        }

        return updatingTransition(
            transitionID: transitionID,
            guardUpdate: .set(normalizedGuard)
        )
    }

    func removingGuard(
        fromTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            guardUpdate: .set(nil)
        )
    }

    func addingEffect(
        _ effectReference: EffectReference,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        let normalizedEffect = effectReference.normalizedForEditor

        guard !normalizedEffect.name.isEmpty,
              let transition = transitions.first(where: { $0.id == transitionID }),
              !transition.effects.contains(normalizedEffect) else {
            return nil
        }

        return updatingTransition(
            transitionID: transitionID,
            effectsUpdate: .set(transition.effects + [normalizedEffect])
        )
    }

    func removingEffect(
        at index: Int,
        fromTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        guard let transition = transitions.first(where: { $0.id == transitionID }),
              transition.effects.indices.contains(index) else {
            return nil
        }

        var updatedEffects = transition.effects
        updatedEffects.remove(at: index)

        return updatingTransition(
            transitionID: transitionID,
            effectsUpdate: .set(updatedEffects)
        )
    }

    private func updatingTransition(
        transitionID: String,
        sourceStateID: String? = nil,
        eventID: String? = nil,
        targetStateID: String? = nil,
        guardUpdate: TransitionGuardUpdate = .keep,
        effectsUpdate: TransitionEffectsUpdate = .keep
    ) -> StateMachineDefinition? {
        let knownStateIDs = Set(states.map(\.id))
        let knownEventIDs = Set(events.map(\.id))

        if let sourceStateID, !knownStateIDs.contains(sourceStateID) {
            return nil
        }

        if let targetStateID, !knownStateIDs.contains(targetStateID) {
            return nil
        }

        if let eventID, !knownEventIDs.contains(eventID) {
            return nil
        }

        var didUpdateTransition = false
        let updatedTransitions = transitions.map { transition in
            guard transition.id == transitionID else {
                return transition
            }

            didUpdateTransition = true

            return TransitionDefinition(
                id: transition.id,
                sourceStateID: sourceStateID ?? transition.sourceStateID,
                eventID: eventID ?? transition.eventID,
                targetStateID: targetStateID ?? transition.targetStateID,
                guard: guardUpdate.resolve(from: transition.guard),
                effects: effectsUpdate.resolve(from: transition.effects)
            )
        }

        guard didUpdateTransition else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: events,
            transitions: updatedTransitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    private enum TransitionGuardUpdate {
        case keep
        case set(GuardReference?)

        func resolve(from currentValue: GuardReference?) -> GuardReference? {
            switch self {
            case .keep:
                return currentValue
            case .set(let newValue):
                return newValue
            }
        }
    }

    private enum TransitionEffectsUpdate {
        case keep
        case set([EffectReference])

        func resolve(from currentValue: [EffectReference]) -> [EffectReference] {
            switch self {
            case .keep:
                return currentValue
            case .set(let newValue):
                return newValue
            }
        }
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

    var normalizedForNewState: PropertyDefinition {
        PropertyDefinition(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }
}

private extension GuardReference {
    var normalizedForEditor: GuardReference {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)

        return GuardReference(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedDescription?.isEmpty == true ? nil : trimmedDescription
        )
    }
}

private extension EffectReference {
    var normalizedForEditor: EffectReference {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)

        return EffectReference(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedDescription?.isEmpty == true ? nil : trimmedDescription
        )
    }
}
