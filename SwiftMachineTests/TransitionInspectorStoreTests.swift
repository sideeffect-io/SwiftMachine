//
//  TransitionInspectorStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct TransitionInspectorStoreTests {

    @Test("Assigning a source state delegates the mutation without emitting presentation commands")
    func assignSourceStateDoesNotEmitPresentationCommands() throws {
        let fixture = try makeTransitionFixture()
        let updatedDefinition = try #require(
            fixture.definition.assigningSourceState(
                stateID: fixture.targetStateID,
                toTransitionID: fixture.transitionID
            )
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTransitionInspectorStore(
            transitionID: fixture.transitionID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            assignSourceState: { transitionID, stateID in
                #expect(transitionID == fixture.transitionID)
                #expect(stateID == fixture.targetStateID)
                return CurrentStateMachineDefinitionSnapshot(
                    definition: updatedDefinition,
                    revision: 2
                )
            }
        )

        store.send(.assignSourceState(fixture.targetStateID))

        #expect(canvasCommands.isEmpty)
    }

    @Test("Updating target-state creation delegates the mutation without emitting presentation commands")
    func updateTargetStateCreationDoesNotEmitPresentationCommands() throws {
        let fixture = try makeTransitionFixture()
        let targetStateCreation = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: "target-property",
                    valueSource: .custom(comment: "Handled by the transition")
                )
            ]
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTransitionInspectorStore(
            transitionID: fixture.transitionID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateTargetStateCreation: { transitionID, receivedTargetStateCreation in
                #expect(transitionID == fixture.transitionID)
                #expect(receivedTargetStateCreation == targetStateCreation)
                return CurrentStateMachineDefinitionSnapshot(
                    definition: fixture.definition,
                    revision: 3
                )
            }
        )

        store.send(.updateTargetStateCreation(targetStateCreation))

        #expect(canvasCommands.isEmpty)
    }
}

@MainActor
private func makeTransitionInspectorStore(
    transitionID: String,
    sendEditorCanvasCommand: @escaping @MainActor @Sendable (EditorCanvasCommand) -> Void = { _ in },
    assignSourceState: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    assignEvent: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    assignNewEvent: @escaping @Sendable (String, String, [PropertyDefinition]) -> CurrentStateMachineDefinitionSnapshot? = { _, _, _ in nil },
    assignTargetState: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    updateTargetStateCreation: @escaping @Sendable (String, TransitionTargetStateCreation) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    assignGuard: @escaping @Sendable (String, GuardReference) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    removeGuard: @escaping @Sendable (String) -> CurrentStateMachineDefinitionSnapshot? = { _ in nil },
    addEffect: @escaping @Sendable (String, EffectReference) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    updateEffect: @escaping @Sendable (String, Int, EffectReference) -> CurrentStateMachineDefinitionSnapshot? = { _, _, _ in nil },
    removeEffect: @escaping @Sendable (String, Int) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil }
) -> TransitionInspectorStore {
    TransitionInspectorStore(
        transitionID: transitionID,
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        assignSourceState: .init(assignSourceState: assignSourceState),
        assignEvent: .init(assignEvent: assignEvent),
        assignNewEvent: .init(assignNewEvent: assignNewEvent),
        assignTargetState: .init(assignTargetState: assignTargetState),
        updateTargetStateCreation: .init(updateTargetStateCreation: updateTargetStateCreation),
        assignGuard: .init(assignGuard: assignGuard),
        removeGuard: .init(removeGuard: removeGuard),
        addEffect: .init(addEffect: addEffect),
        updateEffect: .init(updateEffect: updateEffect),
        removeEffect: .init(removeEffect: removeEffect),
        sendEditorCanvasCommand: .init(send: sendEditorCanvasCommand)
    )
}

private struct TransitionFixture {
    let definition: StateMachineDefinition
    let transitionID: String
    let targetStateID: String
}

private func makeTransitionFixture() throws -> TransitionFixture {
    let initialDefinition = try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
    let addedState = try #require(
        initialDefinition.addingState(named: "Review", properties: [])
    )
    let definitionWithState = addedState.definition
    let addedEvent = try #require(
        definitionWithState.addingEvent(named: "Advance", properties: [])
    )
    let addedTransition = try #require(
        addedEvent.definition.addingTransition(
            sourceStateID: initialDefinition.initialStateID,
            eventID: addedEvent.eventID,
            targetStateID: addedState.stateID
        )
    )

    return TransitionFixture(
        definition: addedTransition.definition,
        transitionID: addedTransition.transitionID,
        targetStateID: addedState.stateID
    )
}
