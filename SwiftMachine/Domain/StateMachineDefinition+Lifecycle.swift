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
        initialStateProperties: [PropertyDefinition],
        types: [PayloadTypeDefinition] = []
    ) -> StateMachineDefinition? {
        let machineName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateName = initialStateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTypes = types.compactMap(Self.normalizedType)

        guard let normalizedProperties = Self.normalizedProperties(
            initialStateProperties,
            using: \.normalizedForEditor
        ) else {
            return nil
        }

        guard normalizedTypes.count == types.count else {
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
            types: normalizedTypes,
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

    func nextAvailableStructTypeName() -> String {
        Self.nextAvailableName(
            prefix: "Struct",
            existingNames: types.map(\.name)
        )
    }

    func nextAvailableEnumTypeName() -> String {
        Self.nextAvailableName(
            prefix: "Enum",
            existingNames: types.map(\.name)
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
            types: types,
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
            types: types,
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
            types: types,
            states: updatedStates,
            events: events,
            transitions: reconciledTransitions(
                types: types,
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
            types: types,
            states: updatedStates,
            events: events,
            transitions: reconciledTransitions(
                types: types,
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
            types: types,
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
            types: types,
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
            types: types,
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
            types: types,
            states: states,
            events: updatedEvents,
            transitions: reconciledTransitions(
                types: types,
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

    func addingStructType() -> (definition: StateMachineDefinition, typeID: String)? {
        addingType(
            named: nextAvailableStructTypeName(),
            kind: .structType(fields: [])
        )
    }

    func addingEnumType() -> (definition: StateMachineDefinition, typeID: String)? {
        addingType(
            named: nextAvailableEnumTypeName(),
            kind: .enumType(cases: [], defaultCaseID: nil)
        )
    }

    func addingType(
        named proposedName: String,
        kind: PayloadTypeKind
    ) -> (definition: StateMachineDefinition, typeID: String)? {
        guard let normalizedType = Self.normalizedType(
            PayloadTypeDefinition(
                name: proposedName,
                kind: kind
            )
        ) else {
            return nil
        }

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            types: types + [normalizedType],
            states: states,
            events: events,
            transitions: reconciledTransitions(
                types: types + [normalizedType],
                states: states,
                events: events,
                transitions: transitions
            )
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return (definition: updatedDefinition, typeID: normalizedType.id)
    }

    func renamingType(
        id typeID: String,
        to proposedName: String
    ) -> StateMachineDefinition? {
        guard let existingType = types.first(where: { $0.id == typeID }) else {
            return nil
        }

        return updatingType(
            PayloadTypeDefinition(
                id: existingType.id,
                name: proposedName,
                kind: existingType.kind
            ),
            forTypeID: typeID
        )
    }

    func updatingType(
        _ updatedType: PayloadTypeDefinition,
        forTypeID typeID: String
    ) -> StateMachineDefinition? {
        guard let normalizedType = Self.normalizedType(updatedType) else {
            return nil
        }

        var didUpdateType = false
        let updatedTypes = types.map { type in
            guard type.id == typeID else {
                return type
            }

            didUpdateType = true
            return normalizedType
        }

        guard didUpdateType else {
            return nil
        }

        let reconciledStates = Self.reconciledStates(
            states,
            types: updatedTypes
        )
        let reconciledEvents = Self.reconciledEvents(
            events,
            types: updatedTypes
        )

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            types: updatedTypes,
            states: reconciledStates,
            events: reconciledEvents,
            transitions: reconciledTransitions(
                types: updatedTypes,
                states: reconciledStates,
                events: reconciledEvents,
                transitions: transitions
            )
        )

        guard updatedDefinition.isValid else {
            return nil
        }

        return updatedDefinition
    }

    func removingType(
        id typeID: String
    ) -> StateMachineDefinition? {
        guard types.contains(where: { $0.id == typeID }),
              !Self.isTypeReferenced(
                typeID,
                inTypes: types,
                states: states,
                events: events
              ) else {
            return nil
        }

        let updatedTypes = types.filter { $0.id != typeID }
        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            types: updatedTypes,
            states: states,
            events: events,
            transitions: reconciledTransitions(
                types: updatedTypes,
                states: states,
                events: events,
                transitions: transitions
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
                types: types,
                states: states,
                events: events
            )
        )

        let updatedDefinition = StateMachineDefinition(
            id: id,
            name: name,
            initialStateID: initialStateID,
            types: types,
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
                    types: types,
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
            types: types,
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
            types: [PayloadTypeDefinition],
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
                    types: types,
                    states: states,
                    events: events
                )
            case .reconcile:
                return StateMachineDefinition.reconciledTargetStateCreation(
                    existing: currentValue,
                    sourceStateID: sourceStateID,
                    eventID: eventID,
                    targetStateID: targetStateID,
                    types: types,
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

    nonisolated private static func normalizedProperties(
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

    nonisolated private static func normalizedType(
        _ type: PayloadTypeDefinition
    ) -> PayloadTypeDefinition? {
        let trimmedName = type.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        let normalizedKind: PayloadTypeKind
        switch type.kind {
        case .structType(let fields):
            guard let normalizedFields = normalizedProperties(
                fields,
                using: \.normalizedForEditor
            ) else {
                return nil
            }

            normalizedKind = .structType(fields: normalizedFields)

        case .enumType(let cases, let defaultCaseID):
            let normalizedCases = cases.map(\.normalizedForEditor)
            let caseNames = normalizedCases.map(\.name)

            guard normalizedCases.allSatisfy({ !$0.name.isEmpty }),
                  Set(caseNames).count == caseNames.count else {
                return nil
            }

            let normalizedDefaultCaseID = defaultCaseID.flatMap { proposedDefaultCaseID in
                normalizedCases.contains(where: { $0.id == proposedDefaultCaseID })
                    ? proposedDefaultCaseID
                    : nil
            }

            normalizedKind = .enumType(
                cases: normalizedCases,
                defaultCaseID: normalizedDefaultCaseID
            )
        }

        return PayloadTypeDefinition(
            id: type.id,
            name: trimmedName,
            kind: normalizedKind
        )
    }

    private static func isTypeReferenced(
        _ typeID: String,
        inTypes types: [PayloadTypeDefinition],
        states: [StateDefinition],
        events: [EventDefinition]
    ) -> Bool {
        let stateReferencesType = states.contains { state in
            state.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }

        if stateReferencesType {
            return true
        }

        let eventReferencesType = events.contains { event in
            event.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }

        if eventReferencesType {
            return true
        }

        return types.contains { type in
            switch type.kind {
            case .structType(let fields):
                return fields.contains(where: { $0.type.referencedTypeID == typeID })
            case .enumType(let cases, _):
                return cases.contains(where: { $0.payloadType?.referencedTypeID == typeID })
            }
        }
    }

    private func reconciledTransitions(
        types: [PayloadTypeDefinition],
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
                    types: types,
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
        types: [PayloadTypeDefinition],
        states: [StateDefinition],
        events: [EventDefinition]
    ) -> TransitionTargetStateCreation {
        guard let targetState = states.first(where: { $0.id == targetStateID }) else {
            return .init()
        }

        let sourceState = states.first(where: { $0.id == sourceStateID })
        let event = events.first(where: { $0.id == eventID })
        let schemaDefinition = StateMachineDefinition(
            id: "schema-definition",
            name: "Schema Definition",
            initialStateID: states.first?.id ?? targetStateID,
            types: types,
            states: states,
            events: events,
            transitions: []
        )
        let sourceProperties = sourceState?.properties ?? []
        let eventProperties = event?.properties ?? []
        let sourceOptions = schemaDefinition.referenceOptions(in: sourceProperties)
        let eventOptions = schemaDefinition.referenceOptions(in: eventProperties)
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
                let targetSchema = schemaDefinition.schema(for: targetProperty)
                let existingValueSource = existingAssignments[targetProperty.id]?.valueSource
                let valueSource = targetSchema.map { targetSchema in
                    reconciledValueSource(
                        existing: existingValueSource,
                        targetName: targetProperty.name,
                        targetType: targetProperty.type,
                        targetSchema: targetSchema,
                        sourceProperties: sourceProperties,
                        eventProperties: eventProperties,
                        sourceOptions: sourceOptions,
                        eventOptions: eventOptions,
                        schemaDefinition: schemaDefinition
                    )
                } ?? .targetDefault

                return TransitionTargetStatePropertyAssignment(
                    targetPropertyID: targetProperty.id,
                    valueSource: valueSource
                )
            }
        )
    }

    private static func reconciledValueSource(
        existing: TransitionTargetStateValueSource?,
        targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition],
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption],
        schemaDefinition: StateMachineDefinition
    ) -> TransitionTargetStateValueSource {
        guard let existing else {
            return suggestedValueSource(
                forName: targetName,
                targetType: targetType,
                targetSchema: targetSchema,
                sourceOptions: sourceOptions,
                eventOptions: eventOptions
            )
        }

        switch existing {
        case .fieldMap(let fields):
            guard case .structType(let targetFields) = targetSchema else {
                return suggestedValueSource(
                    forName: targetName,
                    targetType: targetType,
                    targetSchema: targetSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions
                )
            }

            let existingFieldAssignments = fields.reduce(
                into: [String: TransitionTargetStateFieldAssignment]()
            ) { partialResult, assignment in
                guard partialResult[assignment.fieldID] == nil else {
                    return
                }

                partialResult[assignment.fieldID] = assignment
            }

            return .fieldMap(
                fields: targetFields.map { field in
                    TransitionTargetStateFieldAssignment(
                        fieldID: field.id,
                        valueSource: reconciledValueSource(
                            existing: existingFieldAssignments[field.id]?.valueSource,
                            targetName: field.name,
                            targetType: field.type,
                            targetSchema: field.schema,
                            sourceProperties: sourceProperties,
                            eventProperties: eventProperties,
                            sourceOptions: sourceOptions,
                            eventOptions: eventOptions,
                            schemaDefinition: schemaDefinition
                        )
                    )
                }
            )

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = targetSchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return suggestedValueSource(
                    forName: targetName,
                    targetType: targetType,
                    targetSchema: targetSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions
                )
            }

            let reconciledPayload = resolvedCase.payloadSchema.map { payloadSchema in
                reconciledValueSource(
                    existing: payload,
                    targetName: resolvedCase.name,
                    targetType: resolvedCase.payloadType ?? .string,
                    targetSchema: payloadSchema,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions,
                    schemaDefinition: schemaDefinition
                )
            }

            return .enumCase(
                caseID: caseID,
                payload: reconciledPayload
            )

        default:
            guard isValid(
                valueSource: existing,
                expectedType: targetType,
                expectedSchema: targetSchema,
                sourceProperties: sourceProperties,
                eventProperties: eventProperties,
                schemaDefinition: schemaDefinition
            ) else {
                return suggestedValueSource(
                    forName: targetName,
                    targetType: targetType,
                    targetSchema: targetSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions
                )
            }

            return existing
        }
    }

    private static func suggestedValueSource(
        forName targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        sourceOptions: [PropertyReferenceOption],
        eventOptions: [PropertyReferenceOption]
    ) -> TransitionTargetStateValueSource {
        switch targetSchema {
        case .primitive(let type):
            if let sourceMatch = matchingReference(
                named: targetName,
                type: type,
                schema: .primitive(type: type),
                in: sourceOptions
            ) {
                return .sourceStateProperty(reference: sourceMatch.reference)
            }

            if let eventMatch = matchingReference(
                named: targetName,
                type: type,
                schema: .primitive(type: type),
                in: eventOptions
            ) {
                return .eventProperty(reference: eventMatch.reference)
            }

            return .targetDefault

        case .structType(let fields):
            return .fieldMap(
                fields: fields.map { field in
                    TransitionTargetStateFieldAssignment(
                        fieldID: field.id,
                        valueSource: suggestedValueSource(
                            forName: field.name,
                            targetType: field.type,
                            targetSchema: field.schema,
                            sourceOptions: sourceOptions,
                            eventOptions: eventOptions
                        )
                    )
                }
            )

        case .enumType(let cases, let defaultCaseID):
            if let sourceMatch = matchingReference(
                named: targetName,
                type: targetType,
                schema: targetSchema,
                in: sourceOptions,
                rootOnly: true
            ) {
                return .sourceStateProperty(reference: sourceMatch.reference)
            }

            if let eventMatch = matchingReference(
                named: targetName,
                type: targetType,
                schema: targetSchema,
                in: eventOptions,
                rootOnly: true
            ) {
                return .eventProperty(reference: eventMatch.reference)
            }

            guard let defaultCaseID,
                  let resolvedCase = cases.first(where: { $0.id == defaultCaseID }) else {
                return .targetDefault
            }

            let payload = resolvedCase.payloadSchema.map { payloadSchema in
                suggestedValueSource(
                    forName: resolvedCase.name,
                    targetType: resolvedCase.payloadType ?? .string,
                    targetSchema: payloadSchema,
                    sourceOptions: sourceOptions,
                    eventOptions: eventOptions
                )
            }

            return .enumCase(
                caseID: defaultCaseID,
                payload: payload
            )
        }
    }

    private static func matchingReference(
        named targetName: String,
        type: PropertyType,
        schema: ResolvedPropertySchema,
        in options: [PropertyReferenceOption],
        rootOnly: Bool = false
    ) -> PropertyReferenceOption? {
        options.first { option in
            option.leafName == targetName
                && option.valueType == type
                && option.schema == schema
                && (!rootOnly || option.reference.path.isEmpty)
        }
    }

    private static func isValid(
        valueSource: TransitionTargetStateValueSource,
        expectedType: PropertyType,
        expectedSchema: ResolvedPropertySchema,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition],
        schemaDefinition: StateMachineDefinition
    ) -> Bool {
        switch valueSource {
        case .targetDefault, .custom:
            return true

        case .sourceStateProperty(let reference):
            return schemaDefinition.propertyType(
                for: reference,
                in: sourceProperties
            ) == expectedType
                && schemaDefinition.schema(
                    for: reference,
                    in: sourceProperties
                ) == expectedSchema

        case .eventProperty(let reference):
            return schemaDefinition.propertyType(
                for: reference,
                in: eventProperties
            ) == expectedType
                && schemaDefinition.schema(
                    for: reference,
                    in: eventProperties
                ) == expectedSchema

        case .literal(let literalValue):
            return expectedSchema == .primitive(type: literalValue.type)

        case .fieldMap(let fields):
            guard case .structType(let targetFields) = expectedSchema else {
                return false
            }

            let fieldIDs = fields.map(\.fieldID)
            guard Set(fieldIDs).count == fieldIDs.count else {
                return false
            }

            let targetFieldMap = targetFields.reduce(into: [String: ResolvedPropertyField]()) { partialResult, field in
                partialResult[field.id] = field
            }

            return fields.allSatisfy { fieldAssignment in
                guard let targetField = targetFieldMap[fieldAssignment.fieldID] else {
                    return false
                }

                return isValid(
                    valueSource: fieldAssignment.valueSource,
                    expectedType: targetField.type,
                    expectedSchema: targetField.schema,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    schemaDefinition: schemaDefinition
                )
            }

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = expectedSchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return false
            }

            switch (resolvedCase.payloadSchema, payload) {
            case (nil, nil):
                return true
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case let (.some(payloadSchema), .some(payloadValueSource)):
                return isValid(
                    valueSource: payloadValueSource,
                    expectedType: resolvedCase.payloadType ?? .string,
                    expectedSchema: payloadSchema,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    schemaDefinition: schemaDefinition
                )
            }
        }
    }
}

private extension PropertyDefinition {
    nonisolated var normalizedForEditor: PropertyDefinition {
        PropertyDefinition(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }

    nonisolated var normalizedForNewState: PropertyDefinition {
        PropertyDefinition(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }
}

private extension PayloadEnumCaseDefinition {
    nonisolated var normalizedForEditor: PayloadEnumCaseDefinition {
        PayloadEnumCaseDefinition(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            payloadType: payloadType
        )
    }
}

private extension StateMachineDefinition {
    static func reconciledStates(
        _ states: [StateDefinition],
        types: [PayloadTypeDefinition]
    ) -> [StateDefinition] {
        states.map { state in
            StateDefinition(
                id: state.id,
                name: state.name,
                properties: reconciledProperties(
                    state.properties,
                    types: types
                )
            )
        }
    }

    static func reconciledEvents(
        _ events: [EventDefinition],
        types: [PayloadTypeDefinition]
    ) -> [EventDefinition] {
        events.map { event in
            EventDefinition(
                id: event.id,
                name: event.name,
                properties: reconciledProperties(
                    event.properties,
                    types: types
                )
            )
        }
    }

    static func reconciledProperties(
        _ properties: [PropertyDefinition],
        types: [PayloadTypeDefinition]
    ) -> [PropertyDefinition] {
        let schemaDefinition = StateMachineDefinition(
            id: "property-default-reconciliation",
            name: "Property Default Reconciliation",
            initialStateID: "property-default-reconciliation-state",
            types: types,
            states: [],
            events: [],
            transitions: []
        )

        return properties.map { property in
            guard let propertySchema = schemaDefinition.schema(for: property) else {
                return property
            }

            return PropertyDefinition(
                id: property.id,
                name: property.name,
                type: property.type,
                isOptional: property.isOptional,
                defaultValue: reconciledPropertyDefaultValue(
                    property.defaultValue,
                    expectedType: property.type,
                    expectedSchema: propertySchema
                )
            )
        }
    }

    static func reconciledPropertyDefaultValue(
        _ existing: PropertyDefaultValue?,
        expectedType: PropertyType,
        expectedSchema: ResolvedPropertySchema
    ) -> PropertyDefaultValue? {
        guard let existing else {
            return nil
        }

        switch existing {
        case .string(let value):
            return expectedSchema == .primitive(type: .string) ? .string(value) : nil
        case .integer(let value):
            return expectedSchema == .primitive(type: .integer) ? .integer(value) : nil
        case .double(let value):
            return expectedSchema == .primitive(type: .double) ? .double(value) : nil
        case .boolean(let value):
            return expectedSchema == .primitive(type: .boolean) ? .boolean(value) : nil

        case .structValue(let fields):
            guard case .structType(let targetFields) = expectedSchema else {
                return nil
            }

            let existingFields = fields.reduce(into: [String: PropertyDefaultFieldValue]()) { partialResult, field in
                guard partialResult[field.fieldID] == nil else {
                    return
                }

                partialResult[field.fieldID] = field
            }

            let reconciledFields = targetFields.compactMap { field -> PropertyDefaultFieldValue? in
                guard let existingField = existingFields[field.id],
                      let fieldValue = reconciledPropertyDefaultValue(
                        existingField.value,
                        expectedType: field.type,
                        expectedSchema: field.schema
                      ) else {
                    return nil
                }

                return PropertyDefaultFieldValue(
                    fieldID: field.id,
                    value: fieldValue
                )
            }

            let requiredMissing = targetFields.contains { field in
                !field.isOptional && !reconciledFields.contains(where: { $0.fieldID == field.id })
            }

            return requiredMissing ? nil : .structValue(fields: reconciledFields)

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = expectedSchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return nil
            }

            switch (resolvedCase.payloadSchema, payload) {
            case (nil, _):
                return .enumCase(caseID: caseID, payload: nil)
            case (.some, nil):
                return nil
            case let (.some(payloadSchema), .some(payloadValue)):
                guard let payloadType = resolvedCase.payloadType,
                      let reconciledPayload = reconciledPropertyDefaultValue(
                        payloadValue,
                        expectedType: payloadType,
                        expectedSchema: payloadSchema
                      ) else {
                    return nil
                }

                return .enumCase(caseID: caseID, payload: reconciledPayload)
            }
        }
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
