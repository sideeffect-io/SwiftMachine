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

    @Test("Tapping add event presents the creation prompt and confirmation routes the mutation to the root canvas")
    func createEventRoutesDefinitionMutation() throws {
        let initialDefinition = try makeEventPaletteDefinition()
        let createdEventResult = try #require(
            initialDefinition.addingEvent(named: "Submitted", properties: [])
        )
        var canvasEvents: [EditorCanvasStore.Event] = []

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
                    return DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: createdEventResult.definition,
                            revision: 2
                        ),
                        preferredSelection: nil
                    )
                }
            ),
            deleteEvent: .init(deleteEvent: { _ in nil }),
            sendEditorCanvasEvent: .init(send: { canvasEvents.append($0) })
        )

        store.send(.addEventTapped)
        #expect(store.state.isEventCreationPromptPresented)

        store.send(.confirmEventCreation(name: "Submitted", properties: []))

        #expect(!store.state.isEventCreationPromptPresented)
        #expect(
            canvasEvents == [
                .definitionMutationWasApplied(
                    DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: createdEventResult.definition,
                            revision: 2
                        ),
                        preferredSelection: nil
                    ),
                    transitionPositionOverride: nil
                )
            ]
        )
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
            sendEditorCanvasEvent: .init(send: { _ in })
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
