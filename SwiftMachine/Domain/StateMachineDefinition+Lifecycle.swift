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
        guard let normalizedProperties = Self.normalizedProperties(
            initialStateProperties,
            using: \.normalizedForEditor
        ) else {
            return nil
        }

        guard !machineName.isEmpty, !stateName.isEmpty else {
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

    func nextAvailableEventName() -> String {
        Self.nextAvailableName(
            prefix: "Event",
            existingNames: events.map(\.name)
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
        guard let normalizedProperties = Self.normalizedProperties(
            properties,
            using: \.normalizedForNewState
        ) else {
            return nil
        }

        guard !trimmedName.isEmpty else {
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

    func removingState(
        id stateID: String
    ) -> StateMachineDefinition? {
        guard states.count > 1,
              states.contains(where: { $0.id == stateID }) else {
            return nil
        }

        let updatedStates = states.filter { $0.id != stateID }
        let updatedInitialStateID = stateID == initialStateID
            ? updatedStates[0].id
            : initialStateID
        let updatedTransitions = transitions.filter { transition in
            transition.sourceStateID != stateID && transition.targetStateID != stateID
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: updatedInitialStateID,
            states: updatedStates,
            events: events,
            transitions: updatedTransitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
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
            transitions: reconciledTransitions(
                states: updatedStates,
                events: events,
                transitions: transitions,
                shouldReconcile: { transition in
                    transition.sourceStateID == stateID || transition.targetStateID == stateID
                }
            )
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
        guard let normalizedProperties = Self.normalizedProperties(
            properties,
            using: \.normalizedForEditor
        ) else {
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
            transitions: reconciledTransitions(
                states: updatedStates,
                events: events,
                transitions: transitions,
                shouldReconcile: { transition in
                    transition.sourceStateID == stateID || transition.targetStateID == stateID
                }
            )
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func addingEvent() -> (definition: StateMachineDefinition, eventID: String)? {
        addingEvent(
            named: nextAvailableEventName(),
            properties: []
        )
    }

    func addingEvent(
        named eventName: String,
        properties: [PropertyDefinition]
    ) -> (definition: StateMachineDefinition, eventID: String)? {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedProperties = Self.normalizedProperties(
            properties,
            using: \.normalizedForEditor
        ) else {
            return nil
        }

        guard !trimmedName.isEmpty else {
            return nil
        }

        let newEvent = EventDefinition(
            name: trimmedName,
            properties: normalizedProperties
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

    func renamingEvent(
        id eventID: String,
        to proposedName: String
    ) -> StateMachineDefinition? {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return nil
        }

        var didUpdateEvent = false
        let updatedEvents = events.map { event in
            guard event.id == eventID else {
                return event
            }

            didUpdateEvent = true

            return EventDefinition(
                id: event.id,
                name: trimmedName,
                properties: event.properties
            )
        }

        guard didUpdateEvent else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: updatedEvents,
            transitions: transitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func removingEvent(
        id eventID: String
    ) -> StateMachineDefinition? {
        guard events.contains(where: { $0.id == eventID }) else {
            return nil
        }

        let updatedEvents = events.filter { $0.id != eventID }
        let updatedTransitions = transitions.filter { $0.eventID != eventID }
        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: updatedEvents,
            transitions: updatedTransitions
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func updatingProperties(
        _ properties: [PropertyDefinition],
        forEventID eventID: String
    ) -> StateMachineDefinition? {
        guard let normalizedProperties = Self.normalizedProperties(
            properties,
            using: \.normalizedForEditor
        ) else {
            return nil
        }

        var didUpdateEvent = false
        let updatedEvents = events.map { event in
            guard event.id == eventID else {
                return event
            }

            didUpdateEvent = true

            return EventDefinition(
                id: event.id,
                name: event.name,
                properties: normalizedProperties
            )
        }

        guard didUpdateEvent else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            states: states,
            events: updatedEvents,
            transitions: reconciledTransitions(
                states: states,
                events: updatedEvents,
                transitions: transitions,
                shouldReconcile: { transition in
                    transition.eventID == eventID
                }
            )
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func addingTransition(
        sourceStateID: String,
        eventID: String,
        targetStateID: String,
        targetStateCreation: TransitionTargetStateCreation? = nil
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
            targetStateID: targetStateID,
            targetStateCreation: targetStateCreation ?? Self.reconciledTargetStateCreation(
                existing: .init(),
                sourceStateID: sourceStateID,
                eventID: eventID,
                targetStateID: targetStateID,
                states: states,
                events: events
            )
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
            eventID: eventID,
            targetStateCreationUpdate: .reconcile
        )
    }

    func assigningNewEvent(
        named eventName: String,
        properties: [PropertyDefinition],
        toTransitionID transitionID: String
    ) -> (definition: StateMachineDefinition, eventID: String)? {
        guard let eventResult = addingEvent(
            named: eventName,
            properties: properties
        ),
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
            sourceStateID: stateID,
            targetStateCreationUpdate: .reconcile
        )
    }

    func assigningTargetState(
        stateID: String,
        toTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            targetStateID: stateID,
            targetStateCreationUpdate: .reconcile
        )
    }

    func updatingTargetStateCreation(
        _ targetStateCreation: TransitionTargetStateCreation,
        forTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        updatingTransition(
            transitionID: transitionID,
            targetStateCreationUpdate: .set(targetStateCreation)
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

    func updatingEffect(
        _ effectReference: EffectReference,
        at index: Int,
        inTransitionID transitionID: String
    ) -> StateMachineDefinition? {
        let normalizedEffect = effectReference.normalizedForEditor

        guard !normalizedEffect.name.isEmpty,
              let transition = transitions.first(where: { $0.id == transitionID }),
              transition.effects.indices.contains(index) else {
            return nil
        }

        var updatedEffects = transition.effects
        updatedEffects[index] = normalizedEffect

        let siblingEffects = updatedEffects.enumerated().compactMap { offset, effect in
            offset == index ? nil : effect
        }

        guard !siblingEffects.contains(normalizedEffect) else {
            return nil
        }

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
        targetStateCreationUpdate: TransitionTargetStateCreationUpdate = .keep,
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

            let nextSourceStateID = sourceStateID ?? transition.sourceStateID
            let nextEventID = eventID ?? transition.eventID
            let nextTargetStateID = targetStateID ?? transition.targetStateID

            return TransitionDefinition(
                id: transition.id,
                sourceStateID: nextSourceStateID,
                eventID: nextEventID,
                targetStateID: nextTargetStateID,
                targetStateCreation: targetStateCreationUpdate.resolve(
                    currentValue: transition.targetStateCreation,
                    sourceStateID: nextSourceStateID,
                    eventID: nextEventID,
                    targetStateID: nextTargetStateID,
                    states: states,
                    events: events
                ),
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

    private enum TransitionTargetStateCreationUpdate {
        case keep
        case set(TransitionTargetStateCreation)
        case reconcile

        func resolve(
            currentValue: TransitionTargetStateCreation,
            sourceStateID: String,
            eventID: String,
            targetStateID: String,
            states: [StateDefinition],
            events: [EventDefinition]
        ) -> TransitionTargetStateCreation {
            switch self {
            case .keep:
                return currentValue
            case .set(let newValue):
                return StateMachineDefinition.reconciledTargetStateCreation(
                    existing: newValue,
                    sourceStateID: sourceStateID,
                    eventID: eventID,
                    targetStateID: targetStateID,
                    states: states,
                    events: events
                )
            case .reconcile:
                return StateMachineDefinition.reconciledTargetStateCreation(
                    existing: currentValue,
                    sourceStateID: sourceStateID,
                    eventID: eventID,
                    targetStateID: targetStateID,
                    states: states,
                    events: events
                )
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

    private static func normalizedProperties(
        _ properties: [PropertyDefinition],
        using normalization: (PropertyDefinition) -> PropertyDefinition
    ) -> [PropertyDefinition]? {
        let normalizedProperties = properties.map(normalization)

        guard normalizedProperties.allSatisfy({ !$0.name.isEmpty }) else {
            return nil
        }

        let propertyNames = normalizedProperties.map(\.name)
        guard Set(propertyNames).count == propertyNames.count else {
            return nil
        }

        return normalizedProperties
    }

    private func reconciledTransitions(
        states: [StateDefinition],
        events: [EventDefinition],
        transitions: [TransitionDefinition],
        shouldReconcile: (TransitionDefinition) -> Bool = { _ in true }
    ) -> [TransitionDefinition] {
        transitions.map { transition in
            guard shouldReconcile(transition) else {
                return transition
            }

            return TransitionDefinition(
                id: transition.id,
                sourceStateID: transition.sourceStateID,
                eventID: transition.eventID,
                targetStateID: transition.targetStateID,
                targetStateCreation: Self.reconciledTargetStateCreation(
                    existing: transition.targetStateCreation,
                    sourceStateID: transition.sourceStateID,
                    eventID: transition.eventID,
                    targetStateID: transition.targetStateID,
                    states: states,
                    events: events
                ),
                guard: transition.guard,
                effects: transition.effects
            )
        }
    }

    private static func reconciledTargetStateCreation(
        existing: TransitionTargetStateCreation,
        sourceStateID: String,
        eventID: String,
        targetStateID: String,
        states: [StateDefinition],
        events: [EventDefinition]
    ) -> TransitionTargetStateCreation {
        guard let targetState = states.first(where: { $0.id == targetStateID }) else {
            return .init()
        }

        let sourceState = states.first(where: { $0.id == sourceStateID })
        let event = events.first(where: { $0.id == eventID })
        let existingAssignments = existing.assignments.reduce(
            into: [String: TransitionTargetStatePropertyAssignment]()
        ) { partialResult, assignment in
            guard partialResult[assignment.targetPropertyID] == nil else {
                return
            }

            partialResult[assignment.targetPropertyID] = assignment
        }

        return TransitionTargetStateCreation(
            assignments: targetState.properties.map { targetProperty in
                let preservedAssignment = existingAssignments[targetProperty.id].flatMap { assignment in
                    isValid(
                        assignment: assignment,
                        targetProperty: targetProperty,
                        sourceState: sourceState,
                        event: event
                    ) ? assignment : nil
                }

                return preservedAssignment ?? TransitionTargetStatePropertyAssignment(
                    targetPropertyID: targetProperty.id,
                    valueSource: suggestedValueSource(
                        for: targetProperty,
                        sourceState: sourceState,
                        event: event
                    )
                )
            }
        )
    }

    private static func isValid(
        assignment: TransitionTargetStatePropertyAssignment,
        targetProperty: PropertyDefinition,
        sourceState: StateDefinition?,
        event: EventDefinition?
    ) -> Bool {
        switch assignment.valueSource {
        case .targetDefault:
            return assignment.targetPropertyID == targetProperty.id

        case .sourceStateProperty(let propertyID):
            return assignment.targetPropertyID == targetProperty.id
                && sourceState?.properties.contains(where: {
                    $0.id == propertyID && $0.type == targetProperty.type
                }) == true

        case .eventProperty(let propertyID):
            return assignment.targetPropertyID == targetProperty.id
                && event?.properties.contains(where: {
                    $0.id == propertyID && $0.type == targetProperty.type
                }) == true

        case .literal(let literalValue):
            return assignment.targetPropertyID == targetProperty.id
                && literalValue.type == targetProperty.type
        }
    }

    private static func suggestedValueSource(
        for targetProperty: PropertyDefinition,
        sourceState: StateDefinition?,
        event: EventDefinition?
    ) -> TransitionTargetStateValueSource {
        if let sourceMatch = sourceState?.properties.first(where: {
            $0.name == targetProperty.name && $0.type == targetProperty.type
        }) {
            return .sourceStateProperty(propertyID: sourceMatch.id)
        }

        if let eventMatch = event?.properties.first(where: {
            $0.name == targetProperty.name && $0.type == targetProperty.type
        }) {
            return .eventProperty(propertyID: eventMatch.id)
        }

        return .targetDefault
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
