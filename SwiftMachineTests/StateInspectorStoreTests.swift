//
//  StateInspectorStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct StateInspectorStoreTests {

    @Test("Updating a state name delegates the mutation without emitting presentation commands")
    func updateStateNameDoesNotEmitPresentationCommands() throws {
        let definition = try makeStateInspectorDefinition()
        let stateID = try #require(definition.states.first?.id)
        let updatedDefinition = try #require(
            definition.renamingState(id: stateID, to: "Ready")
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 2
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeStateInspectorStore(
            stateID: stateID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateStateName: { receivedStateID, name in
                #expect(receivedStateID == stateID)
                #expect(name == "Ready")
                return snapshot
            }
        )

        store.send(.updateStateName("Ready"))

        #expect(canvasCommands.isEmpty)
    }

    @Test("Updating state properties delegates the mutation without emitting presentation commands")
    func updateStatePropertiesDoesNotEmitPresentationCommands() throws {
        let definition = try makeStateInspectorDefinition()
        let stateID = try #require(definition.states.first?.id)
        let properties = [
            PropertyDefinition(name: "amount", type: .double),
            PropertyDefinition(name: "coupon", type: .string, isOptional: true)
        ]
        let updatedDefinition = try #require(
            definition.updatingProperties(properties, forStateID: stateID)
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 3
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeStateInspectorStore(
            stateID: stateID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateStateProperties: { receivedStateID, receivedProperties in
                #expect(receivedStateID == stateID)
                #expect(receivedProperties == properties)
                return snapshot
            }
        )

        store.send(.updateStateProperties(properties))

        #expect(canvasCommands.isEmpty)
    }
}

@MainActor
private func makeStateInspectorStore(
    stateID: String,
    sendEditorCanvasCommand: @escaping @MainActor @Sendable (EditorCanvasCommand) -> Void = { _ in },
    updateStateName: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    updateStateProperties: @escaping @Sendable (String, [PropertyDefinition]) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil }
) -> StateInspectorStore {
    StateInspectorStore(
        stateID: stateID,
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        updateStateName: .init(updateStateName: updateStateName),
        updateStateProperties: .init(updateStateProperties: updateStateProperties),
        sendEditorCanvasCommand: .init(send: sendEditorCanvasCommand)
    )
}

private func makeStateInspectorDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
