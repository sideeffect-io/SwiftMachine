//
//  TransitionComposerStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct TransitionComposerStoreTests {

    @Test("Cancelling the composer dismisses the prompt")
    func cancelDismissesPrompt() throws {
        let fixture = try makeTransitionComposerFixture()
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTransitionComposerStore(
            prompt: fixture.prompt,
            sendEditorCanvasCommand: { canvasCommands.append($0) }
        )

        store.send(.cancelRequested)

        #expect(canvasCommands == [.dismissTransitionPrompt])
    }

    @Test("Confirming with an existing event emits presentation commands and dismisses the prompt")
    func confirmWithExistingEventEmitsPresentationCommands() throws {
        let fixture = try makeTransitionComposerFixture()
        let properties = [
            PropertyDefinition(name: "amount", type: .double)
        ]
        let targetStateCreation = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: fixture.targetPropertyID,
                    valueSource: .custom(comment: "Handled by the transition")
                )
            ]
        )
        let eventUpdatedDefinition = try #require(
            fixture.definition.updatingProperties(
                properties,
                forEventID: fixture.eventID
            )
        )
        let transitionResult = try #require(
            eventUpdatedDefinition.addingTransition(
                sourceStateID: fixture.prompt.sourceStateID,
                eventID: fixture.eventID,
                targetStateID: fixture.prompt.targetStateID,
                targetStateCreation: targetStateCreation
            )
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTransitionComposerStore(
            prompt: fixture.prompt,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            createWithExistingEvent: { prompt, eventID, receivedProperties, receivedTargetStateCreation in
                #expect(prompt == fixture.prompt)
                #expect(eventID == fixture.eventID)
                #expect(receivedProperties == properties)
                #expect(receivedTargetStateCreation == targetStateCreation)
                return transitionResult.transitionID
            }
        )

        store.send(
            .confirmWithExistingEvent(
                eventID: fixture.eventID,
                properties: properties,
                targetStateCreation: targetStateCreation
            )
        )

        #expect(
            canvasCommands == [
                .selectWhenAvailable(.transition(id: transitionResult.transitionID)),
                .positionTransitionWhenAvailable(
                    id: transitionResult.transitionID,
                    position: fixture.prompt.anchor
                ),
                .dismissTransitionPrompt
            ]
        )
    }

    @Test("Confirming with a new event emits presentation commands and dismisses the prompt")
    func confirmWithNewEventEmitsPresentationCommands() throws {
        let fixture = try makeTransitionComposerFixture()
        let properties = [
            PropertyDefinition(name: "channel", type: .string, isOptional: true)
        ]
        let targetStateCreation = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: fixture.targetPropertyID,
                    valueSource: .targetDefault
                )
            ]
        )
        let eventResult = try #require(
            fixture.definition.addingEvent(
                named: "Submit",
                properties: properties
            )
        )
        let transitionResult = try #require(
            eventResult.definition.addingTransition(
                sourceStateID: fixture.prompt.sourceStateID,
                eventID: eventResult.eventID,
                targetStateID: fixture.prompt.targetStateID,
                targetStateCreation: targetStateCreation
            )
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTransitionComposerStore(
            prompt: fixture.prompt,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            createWithNewEvent: { prompt, name, receivedProperties, receivedTargetStateCreation in
                #expect(prompt == fixture.prompt)
                #expect(name == "Submit")
                #expect(receivedProperties == properties)
                #expect(receivedTargetStateCreation == targetStateCreation)
                return transitionResult.transitionID
            }
        )

        store.send(
            .confirmWithNewEvent(
                name: "Submit",
                properties: properties,
                targetStateCreation: targetStateCreation
            )
        )

        #expect(
            canvasCommands == [
                .selectWhenAvailable(.transition(id: transitionResult.transitionID)),
                .positionTransitionWhenAvailable(
                    id: transitionResult.transitionID,
                    position: fixture.prompt.anchor
                ),
                .dismissTransitionPrompt
            ]
        )
    }
}

@MainActor
private func makeTransitionComposerStore(
    prompt: StateMachineTransitionPrompt,
    sendEditorCanvasCommand: @escaping @MainActor @Sendable (EditorCanvasCommand) -> Void = { _ in },
    createWithExistingEvent: @escaping @Sendable (
        StateMachineTransitionPrompt,
        String,
        [PropertyDefinition],
        TransitionTargetStateCreation
    ) -> String? = { _, _, _, _ in nil },
    createWithNewEvent: @escaping @Sendable (
        StateMachineTransitionPrompt,
        String,
        [PropertyDefinition],
        TransitionTargetStateCreation
    ) -> String? = { _, _, _, _ in nil }
) -> TransitionComposerStore {
    TransitionComposerStore(
        prompt: prompt,
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        createWithExistingEvent: .init(createTransition: createWithExistingEvent),
        createWithNewEvent: .init(createTransition: createWithNewEvent),
        sendEditorCanvasCommand: .init(send: sendEditorCanvasCommand)
    )
}

private struct TransitionComposerFixture {
    let definition: StateMachineDefinition
    let eventID: String
    let prompt: StateMachineTransitionPrompt
    let targetPropertyID: String
}

private func makeTransitionComposerFixture() throws -> TransitionComposerFixture {
    let baseDefinition = try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
    let secondStateResult = try #require(
        baseDefinition.addingState(
            named: "Review",
            properties: [
                PropertyDefinition(id: "target-amount", name: "amount", type: .double)
            ]
        )
    )
    let eventResult = try #require(
        secondStateResult.definition.addingEvent(
            named: "Advance",
            properties: []
        )
    )
    let targetPropertyID = try #require(
        eventResult.definition.states
            .first(where: { $0.id == secondStateResult.stateID })?
            .properties
            .first(where: { $0.name == "amount" })?
            .id
    )

    return TransitionComposerFixture(
        definition: eventResult.definition,
        eventID: eventResult.eventID,
        prompt: StateMachineTransitionPrompt(
            sourceStateID: eventResult.definition.initialStateID,
            targetStateID: secondStateResult.stateID,
            anchor: StateMachineEditorPoint(x: 640, y: 420)
        ),
        targetPropertyID: targetPropertyID
    )
}
