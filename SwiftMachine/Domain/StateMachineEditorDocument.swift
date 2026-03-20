//
//  StateMachineEditorDocument.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import Foundation

struct StateMachineEditorDocument: Sendable, Codable, Equatable, Hashable {
    static let stateNodeSize = StateMachineEditorSize(width: 220, height: 120)
    static let initialStateOrigin = StateMachineEditorPoint(x: 360, y: 240)
    static let stateOriginOffset = StateMachineEditorPoint(x: 180, y: 120)

    let definition: StateMachineDefinition
    let statePositions: [String: StateMachineEditorPoint]
    let transitionPositions: [String: StateMachineEditorPoint]

    init(
        definition: StateMachineDefinition,
        statePositions: [String: StateMachineEditorPoint],
        transitionPositions: [String: StateMachineEditorPoint] = [:]
    ) {
        self.definition = definition
        self.statePositions = statePositions
        self.transitionPositions = transitionPositions
    }

    private enum CodingKeys: String, CodingKey {
        case definition
        case statePositions
        case transitionPositions
        case eventPositions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        definition = try container.decode(StateMachineDefinition.self, forKey: .definition)
        statePositions = try container.decode(
            [String: StateMachineEditorPoint].self,
            forKey: .statePositions
        )

        if let storedTransitionPositions = try container.decodeIfPresent(
            [String: StateMachineEditorPoint].self,
            forKey: .transitionPositions
        ) {
            transitionPositions = storedTransitionPositions
        } else {
            let legacyEventPositions = try container.decodeIfPresent(
                [String: StateMachineEditorPoint].self,
                forKey: .eventPositions
            ) ?? [:]
            transitionPositions = Self.transitionPositions(
                migratingLegacyEventPositions: legacyEventPositions,
                for: definition
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(definition, forKey: .definition)
        try container.encode(statePositions, forKey: .statePositions)
        try container.encode(transitionPositions, forKey: .transitionPositions)
    }

    static func bootstrap(definition: StateMachineDefinition) -> StateMachineEditorDocument {
        let orderedStates = definition.states.sorted { lhs, rhs in
            if lhs.id == definition.initialStateID {
                return true
            }

            if rhs.id == definition.initialStateID {
                return false
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let positions = Dictionary(
            uniqueKeysWithValues: orderedStates.enumerated().map { index, state in
                let offsetX = stateOriginOffset.x * Double(index)
                let offsetY = stateOriginOffset.y * Double(index)
                return (
                    state.id,
                    initialStateOrigin.translatingBy(dx: offsetX, dy: offsetY)
                )
            }
        )

        return StateMachineEditorDocument(
            definition: definition,
            statePositions: positions
        )
    }

    func position(for stateID: String) -> StateMachineEditorPoint {
        statePositions[stateID] ?? Self.initialStateOrigin
    }

    func transitionPosition(for transitionID: String) -> StateMachineEditorPoint? {
        transitionPositions[transitionID]
    }

    func frame(for stateID: String) -> StateMachineEditorRect {
        StateMachineEditorRect(
            origin: position(for: stateID),
            size: Self.stateNodeSize
        )
    }

    func stateID(at point: StateMachineEditorPoint) -> String? {
        definition.states
            .reversed()
            .first { frame(for: $0.id).contains(point) }?
            .id
    }

    func suggestedStateName() -> String {
        definition.nextAvailableStateName()
    }

    func suggestedEventName() -> String {
        definition.nextAvailableEventName()
    }

    func suggestedStructTypeName() -> String {
        definition.nextAvailableStructTypeName()
    }

    func suggestedEnumTypeName() -> String {
        definition.nextAvailableEnumTypeName()
    }

    func addingState() -> (document: StateMachineEditorDocument, stateID: String)? {
        addingState(
            named: suggestedStateName(),
            properties: []
        )
    }

    func addingState(
        named proposedName: String,
        properties: [PropertyDefinition]
    ) -> (document: StateMachineEditorDocument, stateID: String)? {
        guard let result = definition.addingState(
            named: proposedName,
            properties: properties
        ) else {
            return nil
        }

        let positionIndex = Double(result.definition.states.count - 1)
        let initialOrigin = position(for: result.definition.initialStateID)
        let newPosition = initialOrigin.translatingBy(
            dx: Self.stateOriginOffset.x * positionIndex,
            dy: Self.stateOriginOffset.y * positionIndex
        )

        var updatedPositions = statePositions
        updatedPositions[result.stateID] = newPosition

        return (
            document: StateMachineEditorDocument(
                definition: result.definition,
                statePositions: updatedPositions,
                transitionPositions: transitionPositions
            ),
            stateID: result.stateID
        )
    }

    func addingEvent() -> (document: StateMachineEditorDocument, eventID: String)? {
        guard let result = definition.addingEvent() else {
            return nil
        }

        return (
            document: preservingLayout(with: result.definition),
            eventID: result.eventID
        )
    }

    func addingEvent(
        named eventName: String,
        properties: [PropertyDefinition]
    ) -> (document: StateMachineEditorDocument, eventID: String)? {
        guard let result = definition.addingEvent(
            named: eventName,
            properties: properties
        ) else {
            return nil
        }

        return (
            document: preservingLayout(with: result.definition),
            eventID: result.eventID
        )
    }

    func renamingState(
        id stateID: String,
        to proposedName: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.renamingState(
            id: stateID,
            to: proposedName
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func removingState(
        id stateID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingState(id: stateID) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func renamingEvent(
        id eventID: String,
        to proposedName: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.renamingEvent(
            id: eventID,
            to: proposedName
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func updatingStateProperties(
        _ properties: [PropertyDefinition],
        forStateID stateID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.updatingProperties(
            properties,
            forStateID: stateID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func removingEvent(
        id eventID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingEvent(id: eventID) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func updatingEventProperties(
        _ properties: [PropertyDefinition],
        forEventID eventID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.updatingProperties(
            properties,
            forEventID: eventID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func addingStructType() -> (document: StateMachineEditorDocument, typeID: String)? {
        guard let result = definition.addingStructType() else {
            return nil
        }

        return (
            document: preservingLayout(with: result.definition),
            typeID: result.typeID
        )
    }

    func addingEnumType() -> (document: StateMachineEditorDocument, typeID: String)? {
        guard let result = definition.addingEnumType() else {
            return nil
        }

        return (
            document: preservingLayout(with: result.definition),
            typeID: result.typeID
        )
    }

    func renamingType(
        id typeID: String,
        to proposedName: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.renamingType(
            id: typeID,
            to: proposedName
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func updatingType(
        _ type: PayloadTypeDefinition,
        forTypeID typeID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.updatingType(
            type,
            forTypeID: typeID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func removingType(
        id typeID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingType(id: typeID) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func movingState(
        id stateID: String,
        to position: StateMachineEditorPoint
    ) -> StateMachineEditorDocument {
        guard statePositions[stateID] != nil else {
            return self
        }

        var updatedPositions = statePositions
        updatedPositions[stateID] = position

        return StateMachineEditorDocument(
            definition: definition,
            statePositions: updatedPositions,
            transitionPositions: transitionPositions
        )
    }

    func movingTransition(
        id transitionID: String,
        to position: StateMachineEditorPoint
    ) -> StateMachineEditorDocument {
        guard definition.transitions.contains(where: { $0.id == transitionID }) else {
            return self
        }

        var updatedPositions = transitionPositions
        updatedPositions[transitionID] = position

        return StateMachineEditorDocument(
            definition: definition,
            statePositions: statePositions,
            transitionPositions: updatedPositions
        )
    }

    func addingTransition(
        sourceStateID: String,
        targetStateID: String,
        eventID: String,
        targetStateCreation: TransitionTargetStateCreation? = nil,
        transitionPosition: StateMachineEditorPoint? = nil
    ) -> (document: StateMachineEditorDocument, transitionID: String)? {
        guard let result = definition.addingTransition(
            sourceStateID: sourceStateID,
            eventID: eventID,
            targetStateID: targetStateID,
            targetStateCreation: targetStateCreation
        ) else {
            return nil
        }

        return (
            document: preservingLayout(
                with: result.definition,
                transitionPositionOverrides: transitionPosition.map {
                    [result.transitionID: $0]
                } ?? [:]
            ),
            transitionID: result.transitionID
        )
    }

    func addingTransition(
        sourceStateID: String,
        targetStateID: String,
        newEventName: String,
        eventProperties: [PropertyDefinition],
        targetStateCreation: TransitionTargetStateCreation? = nil,
        transitionPosition: StateMachineEditorPoint? = nil
    ) -> (document: StateMachineEditorDocument, transitionID: String, eventID: String)? {
        guard let eventResult = definition.addingEvent(
            named: newEventName,
            properties: eventProperties
        ) else {
            return nil
        }

        guard let transitionResult = eventResult.definition.addingTransition(
            sourceStateID: sourceStateID,
            eventID: eventResult.eventID,
            targetStateID: targetStateID,
            targetStateCreation: targetStateCreation
        ) else {
            return nil
        }

        return (
            document: preservingLayout(
                with: transitionResult.definition,
                transitionPositionOverrides: transitionPosition.map {
                    [transitionResult.transitionID: $0]
                } ?? [:]
            ),
            transitionID: transitionResult.transitionID,
            eventID: eventResult.eventID
        )
    }

    func assigningEvent(
        eventID: String,
        toTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.assigningEvent(
            eventID: eventID,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func assigningNewEvent(
        named eventName: String,
        properties: [PropertyDefinition],
        toTransitionID transitionID: String
    ) -> (document: StateMachineEditorDocument, eventID: String)? {
        guard let result = definition.assigningNewEvent(
            named: eventName,
            properties: properties,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return (
            document: preservingLayout(with: result.definition),
            eventID: result.eventID
        )
    }

    func assigningSourceState(
        stateID: String,
        toTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.assigningSourceState(
            stateID: stateID,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func assigningTargetState(
        stateID: String,
        toTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.assigningTargetState(
            stateID: stateID,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func updatingTransitionTargetStateCreation(
        _ targetStateCreation: TransitionTargetStateCreation,
        forTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.updatingTargetStateCreation(
            targetStateCreation,
            forTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func assigningGuard(
        _ guardReference: GuardReference,
        toTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.assigningGuard(
            guardReference,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func removingGuard(
        fromTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingGuard(
            fromTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func addingEffect(
        _ effectReference: EffectReference,
        toTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.addingEffect(
            effectReference,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func updatingEffect(
        _ effectReference: EffectReference,
        at index: Int,
        inTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.updatingEffect(
            effectReference,
            at: index,
            inTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    func removingEffect(
        at index: Int,
        fromTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingEffect(
            at: index,
            fromTransitionID: transitionID
        ) else {
            return nil
        }

        return preservingLayout(with: updatedDefinition)
    }

    private func preservingLayout(
        with updatedDefinition: StateMachineDefinition,
        transitionPositionOverrides: [String: StateMachineEditorPoint] = [:]
    ) -> StateMachineEditorDocument {
        let validStateIDs = Set(updatedDefinition.states.map(\.id))
        let validTransitionIDs = Set(updatedDefinition.transitions.map(\.id))
        let updatedStatePositions = statePositions.filter { validStateIDs.contains($0.key) }
        var updatedTransitionPositions = transitionPositions.filter { validTransitionIDs.contains($0.key) }

        for (transitionID, position) in transitionPositionOverrides where validTransitionIDs.contains(transitionID) {
            updatedTransitionPositions[transitionID] = position
        }

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: updatedStatePositions,
            transitionPositions: updatedTransitionPositions
        )
    }

    private static func transitionPositions(
        migratingLegacyEventPositions legacyEventPositions: [String: StateMachineEditorPoint],
        for definition: StateMachineDefinition
    ) -> [String: StateMachineEditorPoint] {
        let halfLegacyWidth = 110.0
        let halfLegacyHeight = 48.0

        return Dictionary(
            uniqueKeysWithValues: definition.transitions.compactMap { transition in
                guard let legacyOrigin = legacyEventPositions[transition.eventID] else {
                    return nil
                }

                return (
                    transition.id,
                    legacyOrigin.translatingBy(
                        dx: halfLegacyWidth,
                        dy: halfLegacyHeight
                    )
                )
            }
        )
    }
}
