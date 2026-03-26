//
//  StateMachineEditorLayout.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct StateMachineEditorLayout: Sendable, Codable, Equatable, Hashable {
    static let stateNodeSize = StateMachineEditorSize(width: 220, height: 120)
    static let initialStateOrigin = StateMachineEditorPoint(x: 360, y: 240)
    static let stateOriginOffset = StateMachineEditorPoint(x: 180, y: 120)

    let statePositions: [String: StateMachineEditorPoint]
    let transitionPositions: [String: StateMachineEditorPoint]

    init(
        statePositions: [String: StateMachineEditorPoint],
        transitionPositions: [String: StateMachineEditorPoint] = [:]
    ) {
        self.statePositions = statePositions
        self.transitionPositions = transitionPositions
    }

    static let empty = StateMachineEditorLayout(statePositions: [:], transitionPositions: [:])

    static func bootstrap(for definition: StateMachineDefinition) -> StateMachineEditorLayout {
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

        return StateMachineEditorLayout(statePositions: positions)
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

    func stateID(
        at point: StateMachineEditorPoint,
        in definition: StateMachineDefinition
    ) -> String? {
        definition.states
            .reversed()
            .first { frame(for: $0.id).contains(point) }?
            .id
    }

    func movingState(
        id stateID: String,
        to position: StateMachineEditorPoint
    ) -> StateMachineEditorLayout {
        guard statePositions[stateID] != nil else {
            return self
        }

        var updatedPositions = statePositions
        updatedPositions[stateID] = position

        return StateMachineEditorLayout(
            statePositions: updatedPositions,
            transitionPositions: transitionPositions
        )
    }

    func movingTransition(
        id transitionID: String,
        to position: StateMachineEditorPoint
    ) -> StateMachineEditorLayout {
        var updatedPositions = transitionPositions
        updatedPositions[transitionID] = position

        return StateMachineEditorLayout(
            statePositions: statePositions,
            transitionPositions: updatedPositions
        )
    }

    func reconciled(
        from previousDefinition: StateMachineDefinition?,
        to definition: StateMachineDefinition,
        transitionPositionOverrides: [String: StateMachineEditorPoint] = [:]
    ) -> StateMachineEditorLayout {
        guard previousDefinition != nil else {
            return Self.bootstrap(for: definition)
        }

        let validStateIDs = Set(definition.states.map(\.id))
        let validTransitionIDs = Set(definition.transitions.map(\.id))

        var updatedStatePositions = statePositions.filter { validStateIDs.contains($0.key) }
        var updatedTransitionPositions = transitionPositions.filter { validTransitionIDs.contains($0.key) }

        let initialOrigin = updatedStatePositions[definition.initialStateID] ?? Self.initialStateOrigin
        let missingStates = definition.states.filter { updatedStatePositions[$0.id] == nil }

        for (index, state) in missingStates.enumerated() {
            let positionIndex = Double(updatedStatePositions.count + index)
            updatedStatePositions[state.id] = initialOrigin.translatingBy(
                dx: Self.stateOriginOffset.x * positionIndex,
                dy: Self.stateOriginOffset.y * positionIndex
            )
        }

        for (transitionID, position) in transitionPositionOverrides where validTransitionIDs.contains(transitionID) {
            updatedTransitionPositions[transitionID] = position
        }

        return StateMachineEditorLayout(
            statePositions: updatedStatePositions,
            transitionPositions: updatedTransitionPositions
        )
    }

    static func transitionPositions(
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
