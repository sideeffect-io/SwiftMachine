//
//  EditorCanvasStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct EditorCanvasStoreTests {

    @Test("Starting the canvas store enables definition observation and keeps the wizard phase when there is no machine")
    func startEnablesObservationFromEmptySnapshot() {
        let store = EditorCanvasStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            )
        )

        store.start()

        #expect(store.state.isObservingDefinition)
        #expect(store.state.phase == .wizard)
    }

    @Test("Applying a definition mutation enters editing mode and honors the preferred selection")
    func definitionMutationReconcilesSelection() throws {
        let definition = try makeCanvasDefinition()
        let addedStateResult = try #require(
            definition.addingState(named: "Review", properties: [])
        )

        let store = EditorCanvasStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            )
        )

        store.send(
            .definitionMutationWasApplied(
                DefinitionMutationResult(
                    snapshot: CurrentStateMachineDefinitionSnapshot(
                        definition: addedStateResult.definition,
                        revision: 1
                    ),
                    preferredSelection: .state(id: addedStateResult.stateID)
                ),
                transitionPositionOverride: nil
            )
        )

        #expect(store.state.phase == .editing)
        #expect(store.selectedStateID == addedStateResult.stateID)
        #expect(store.state.snapshot.revision == 1)
    }

    @Test("Connection drag completion creates a transition prompt")
    func completeConnectionDragCreatesPrompt() throws {
        let definition = try makeTwoStateCanvasDefinition()
        let sourceStateID = try #require(definition.states.first?.id)
        let targetStateID = try #require(definition.states.last?.id)
        let promptAnchor = StateMachineEditorPoint(x: 640, y: 420)

        let store = EditorCanvasStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            )
        )

        store.send(.startConnectionDrag(sourceStateID: sourceStateID, location: .init(x: 400, y: 280)))
        store.send(.completeConnectionDrag(targetStateID: targetStateID, promptLocation: promptAnchor))

        #expect(store.state.connectionDraft == nil)
        #expect(store.state.transitionPrompt == StateMachineTransitionPrompt(
            sourceStateID: sourceStateID,
            targetStateID: targetStateID,
            anchor: promptAnchor
        ))
        #expect(store.state.selection == nil)
    }

    @Test("Snapshot reconciliation clears a selection whose entity disappeared")
    func snapshotReconciliationClearsMissingSelection() throws {
        let definition = try makeTwoStateCanvasDefinition()
        let removableStateID = try #require(definition.states.last?.id)
        let updatedDefinition = try #require(definition.removingState(id: removableStateID))

        let store = EditorCanvasStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            )
        )

        store.send(.selectState(id: removableStateID))
        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: updatedDefinition,
                    revision: 2
                )
            )
        )

        #expect(store.state.selection == nil)
    }
}

private func makeCanvasDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}

private func makeTwoStateCanvasDefinition() throws -> StateMachineDefinition {
    let definition = try makeCanvasDefinition()
    return try #require(definition.addingState(named: "Review", properties: [])?.definition)
}
