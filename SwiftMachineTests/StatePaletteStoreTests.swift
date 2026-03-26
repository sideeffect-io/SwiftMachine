//
//  StatePaletteStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct StatePaletteStoreTests {

    @Test("Tapping add state presents the creation prompt and confirmation emits a selection command")
    func createStateEmitsSelectionCommand() throws {
        let initialDefinition = try makePaletteDefinition()
        let createdStateResult = try #require(
            initialDefinition.addingState(named: "Review", properties: [])
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = StatePaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createState: .init(
                createState: { name, properties in
                    #expect(name == "Review")
                    #expect(properties.isEmpty)
                    return createdStateResult.stateID
                }
            ),
            deleteState: .init(deleteState: { _ in nil }),
            sendEditorCanvasCommand: .init(send: { canvasCommands.append($0) })
        )

        store.send(.addStateTapped)
        #expect(store.state.isStateCreationPromptPresented)

        store.send(.confirmStateCreation(name: "Review", properties: []))

        #expect(!store.state.isStateCreationPromptPresented)
        #expect(
            canvasCommands == [
                .selectWhenAvailable(.state(id: createdStateResult.stateID))
            ]
        )
    }

    @Test("A snapshot update refreshes the local definition snapshot")
    func snapshotUpdateRefreshesDefinition() throws {
        let definition = try makePaletteDefinition()
        let updatedDefinition = try #require(definition.addingState(named: "Review", properties: [])?.definition)

        let store = StatePaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createState: .init(createState: { _, _ in nil }),
            deleteState: .init(deleteState: { _ in nil }),
            sendEditorCanvasCommand: .init(send: { _ in })
        )

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: updatedDefinition,
                    revision: 2
                )
            )
        )

        #expect(store.state.snapshot.definition == updatedDefinition)
        #expect(store.states.count == 2)
    }
}

private func makePaletteDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
