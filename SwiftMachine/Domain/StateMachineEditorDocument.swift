//
//  StateMachineEditorDocument.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import Foundation

struct StateMachineEditorDocument: Sendable, Codable, Equatable, Hashable {
    static let stateNodeSize = StateMachineEditorLayout.stateNodeSize
    static let initialStateOrigin = StateMachineEditorLayout.initialStateOrigin
    static let stateOriginOffset = StateMachineEditorLayout.stateOriginOffset

    let definition: StateMachineDefinition
    let layout: StateMachineEditorLayout

    var statePositions: [String: StateMachineEditorPoint] {
        layout.statePositions
    }

    var transitionPositions: [String: StateMachineEditorPoint] {
        layout.transitionPositions
    }

    init(
        definition: StateMachineDefinition,
        layout: StateMachineEditorLayout
    ) {
        self.definition = definition
        self.layout = layout
    }

    init(
        definition: StateMachineDefinition,
        statePositions: [String: StateMachineEditorPoint],
        transitionPositions: [String: StateMachineEditorPoint] = [:]
    ) {
        self.init(
            definition: definition,
            layout: StateMachineEditorLayout(
                statePositions: statePositions,
                transitionPositions: transitionPositions
            )
        )
    }

    private enum CodingKeys: String, CodingKey {
        case definition
        case statePositions
        case transitionPositions
        case eventPositions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let definition = try container.decode(StateMachineDefinition.self, forKey: .definition)
        let statePositions = try container.decode(
            [String: StateMachineEditorPoint].self,
            forKey: .statePositions
        )

        if let storedTransitionPositions = try container.decodeIfPresent(
            [String: StateMachineEditorPoint].self,
            forKey: .transitionPositions
        ) {
            self.init(
                definition: definition,
                statePositions: statePositions,
                transitionPositions: storedTransitionPositions
            )
        } else {
            let legacyEventPositions = try container.decodeIfPresent(
                [String: StateMachineEditorPoint].self,
                forKey: .eventPositions
            ) ?? [:]

            self.init(
                definition: definition,
                statePositions: statePositions,
                transitionPositions: StateMachineEditorLayout.transitionPositions(
                    migratingLegacyEventPositions: legacyEventPositions,
                    for: definition
                )
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
        StateMachineEditorDocument(
            definition: definition,
            layout: .bootstrap(for: definition)
        )
    }

    func position(for stateID: String) -> StateMachineEditorPoint {
        layout.position(for: stateID)
    }

    func transitionPosition(for transitionID: String) -> StateMachineEditorPoint? {
        layout.transitionPosition(for: transitionID)
    }

    func frame(for stateID: String) -> StateMachineEditorRect {
        layout.frame(for: stateID)
    }

    func stateID(at point: StateMachineEditorPoint) -> String? {
        layout.stateID(at: point, in: definition)
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

        return (
            document: preservingLayout(with: result.definition),
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

        return StateMachineEditorDocument(
            definition: definition,
            layout: layout.movingState(id: stateID, to: position)
        )
    }

    func movingTransition(
        id transitionID: String,
        to position: StateMachineEditorPoint
    ) -> StateMachineEditorDocument {
        guard definition.transitions.contains(where: { $0.id == transitionID }) else {
            return self
        }

        return StateMachineEditorDocument(
            definition: definition,
            layout: layout.movingTransition(id: transitionID, to: position)
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
        StateMachineEditorDocument(
            definition: updatedDefinition,
            layout: layout.reconciled(
                from: definition,
                to: updatedDefinition,
                transitionPositionOverrides: transitionPositionOverrides
            )
        )
    }
}
