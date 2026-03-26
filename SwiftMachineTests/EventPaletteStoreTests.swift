//
//  EventPaletteStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct EventPaletteStoreTests {

    @Test("Tapping add event presents the creation prompt and confirmation avoids presentation commands")
    func createEventDoesNotEmitPresentationCommands() throws {
        let initialDefinition = try makeEventPaletteDefinition()
        let createdEventResult = try #require(
            initialDefinition.addingEvent(named: "Submitted", properties: [])
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = EventPaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createEvent: .init(
                createEvent: { name, properties in
                    #expect(name == "Submitted")
                    #expect(properties.isEmpty)
                    return CurrentStateMachineDefinitionSnapshot(
                        definition: createdEventResult.definition,
                        revision: 2
                    )
                }
            ),
            deleteEvent: .init(deleteEvent: { _ in nil }),
            sendEditorCanvasCommand: .init(send: { canvasCommands.append($0) })
        )

        store.send(.addEventTapped)
        #expect(store.state.isEventCreationPromptPresented)

        store.send(.confirmEventCreation(name: "Submitted", properties: []))

        #expect(!store.state.isEventCreationPromptPresented)
        #expect(canvasCommands.isEmpty)
    }

    @Test("A snapshot update refreshes the local event definition snapshot")
    func snapshotUpdateRefreshesDefinition() throws {
        let definition = try makeEventPaletteDefinition()
        let updatedDefinition = try #require(definition.addingEvent(named: "Submitted", properties: [])?.definition)

        let store = EventPaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createEvent: .init(createEvent: { _, _ in nil }),
            deleteEvent: .init(deleteEvent: { _ in nil }),
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
        #expect(store.events.count == 1)
    }
}

private func makeEventPaletteDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
