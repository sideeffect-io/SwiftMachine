//
//  EventInspectorStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct EventInspectorStoreTests {

    @Test("Updating an event name delegates the mutation without emitting presentation commands")
    func updateEventNameDoesNotEmitPresentationCommands() throws {
        let fixture = try makeEventInspectorFixture()
        let updatedDefinition = try #require(
            fixture.definition.renamingEvent(id: fixture.eventID, to: "Submitted")
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 2
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeEventInspectorStore(
            eventID: fixture.eventID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateEventName: { receivedEventID, name in
                #expect(receivedEventID == fixture.eventID)
                #expect(name == "Submitted")
                return snapshot
            }
        )

        store.send(.updateEventName("Submitted"))

        #expect(canvasCommands.isEmpty)
    }

    @Test("Updating event properties delegates the mutation without emitting presentation commands")
    func updateEventPropertiesDoesNotEmitPresentationCommands() throws {
        let fixture = try makeEventInspectorFixture()
        let properties = [
            PropertyDefinition(name: "amount", type: .double),
            PropertyDefinition(name: "channel", type: .string, isOptional: true)
        ]
        let updatedDefinition = try #require(
            fixture.definition.updatingProperties(properties, forEventID: fixture.eventID)
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 3
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeEventInspectorStore(
            eventID: fixture.eventID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateEventProperties: { receivedEventID, receivedProperties in
                #expect(receivedEventID == fixture.eventID)
                #expect(receivedProperties == properties)
                return snapshot
            }
        )

        store.send(.updateEventProperties(properties))

        #expect(canvasCommands.isEmpty)
    }
}

@MainActor
private func makeEventInspectorStore(
    eventID: String,
    sendEditorCanvasCommand: @escaping @MainActor @Sendable (EditorCanvasCommand) -> Void = { _ in },
    updateEventName: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    updateEventProperties: @escaping @Sendable (String, [PropertyDefinition]) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil }
) -> EventInspectorStore {
    EventInspectorStore(
        eventID: eventID,
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        updateEventName: .init(updateEventName: updateEventName),
        updateEventProperties: .init(updateEventProperties: updateEventProperties),
        sendEditorCanvasCommand: .init(send: sendEditorCanvasCommand)
    )
}

private struct EventInspectorFixture {
    let definition: StateMachineDefinition
    let eventID: String
}

private func makeEventInspectorFixture() throws -> EventInspectorFixture {
    let definition = try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
    let addedEvent = try #require(
        definition.addingEvent(named: "Submit", properties: [])
    )

    return EventInspectorFixture(
        definition: addedEvent.definition,
        eventID: addedEvent.eventID
    )
}
