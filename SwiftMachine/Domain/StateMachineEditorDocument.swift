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

    init(
        definition: StateMachineDefinition,
        statePositions: [String: StateMachineEditorPoint]
    ) {
        self.definition = definition
        self.statePositions = statePositions
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
                statePositions: updatedPositions
            ),
            stateID: result.stateID
        )
    }

    func addingEvent() -> (document: StateMachineEditorDocument, eventID: String)? {
        guard let result = definition.addingEvent() else {
            return nil
        }

        return (
            document: StateMachineEditorDocument(
                definition: result.definition,
                statePositions: statePositions
            ),
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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
            statePositions: updatedPositions
        )
    }

    func addingTransition(
        sourceStateID: String,
        targetStateID: String,
        eventID: String
    ) -> (document: StateMachineEditorDocument, transitionID: String)? {
        guard let result = definition.addingTransition(
            sourceStateID: sourceStateID,
            eventID: eventID,
            targetStateID: targetStateID
        ) else {
            return nil
        }

        return (
            document: StateMachineEditorDocument(
                definition: result.definition,
                statePositions: statePositions
            ),
            transitionID: result.transitionID
        )
    }

    func addingTransition(
        sourceStateID: String,
        targetStateID: String,
        newEventName: String
    ) -> (document: StateMachineEditorDocument, transitionID: String, eventID: String)? {
        guard let eventResult = definition.addingEvent(named: newEventName) else {
            return nil
        }

        guard let transitionResult = eventResult.definition.addingTransition(
            sourceStateID: sourceStateID,
            eventID: eventResult.eventID,
            targetStateID: targetStateID
        ) else {
            return nil
        }

        return (
            document: StateMachineEditorDocument(
                definition: transitionResult.definition,
                statePositions: statePositions
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
    }

    func assigningNewEvent(
        named eventName: String,
        toTransitionID transitionID: String
    ) -> (document: StateMachineEditorDocument, eventID: String)? {
        guard let result = definition.assigningNewEvent(
            named: eventName,
            toTransitionID: transitionID
        ) else {
            return nil
        }

        return (
            document: StateMachineEditorDocument(
                definition: result.definition,
                statePositions: statePositions
            ),
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
    }

    func removingGuard(
        fromTransitionID transitionID: String
    ) -> StateMachineEditorDocument? {
        guard let updatedDefinition = definition.removingGuard(
            fromTransitionID: transitionID
        ) else {
            return nil
        }

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
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

        return StateMachineEditorDocument(
            definition: updatedDefinition,
            statePositions: statePositions
        )
    }
}
