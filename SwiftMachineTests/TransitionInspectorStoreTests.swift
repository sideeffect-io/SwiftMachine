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

    @Test("Assigning a source state routes the mutation to the root canvas")
    func assignSourceStateRoutesDefinitionMutation() throws {
        let fixture = try makeTransitionFixture()
        let updatedDefinition = try #require(
            fixture.definition.assigningSourceState(
                stateID: fixture.targetStateID,
                toTransitionID: fixture.transitionID
            )
        )
        var canvasEvents: [EditorCanvasStore.Event] = []

        let store = makeTransitionInspectorStore(
            transitionID: fixture.transitionID,
            sendEditorCanvasEvent: { canvasEvents.append($0) },
            assignSourceState: { transitionID, stateID in
                #expect(transitionID == fixture.transitionID)
                #expect(stateID == fixture.targetStateID)
                return DefinitionMutationResult(
                    snapshot: CurrentStateMachineDefinitionSnapshot(
                        definition: updatedDefinition,
                        revision: 2
                    ),
                    preferredSelection: .transition(id: fixture.transitionID)
                )
            }
        )

        store.send(.assignSourceState(fixture.targetStateID))

        #expect(
            canvasEvents == [
                .definitionMutationWasApplied(
                    DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: updatedDefinition,
                            revision: 2
                        ),
                        preferredSelection: .transition(id: fixture.transitionID)
                    ),
                    transitionPositionOverride: nil
                )
            ]
        )
    }

    @Test("Updating target-state creation routes the mutation to the root canvas")
    func updateTargetStateCreationRoutesDefinitionMutation() throws {
        let fixture = try makeTransitionFixture()
        let targetStateCreation = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: "target-property",
                    valueSource: .custom(comment: "Handled by the transition")
                )
            ]
        )
        var canvasEvents: [EditorCanvasStore.Event] = []

        let store = makeTransitionInspectorStore(
            transitionID: fixture.transitionID,
            sendEditorCanvasEvent: { canvasEvents.append($0) },
            updateTargetStateCreation: { transitionID, receivedTargetStateCreation in
                #expect(transitionID == fixture.transitionID)
                #expect(receivedTargetStateCreation == targetStateCreation)
                return DefinitionMutationResult(
                    snapshot: CurrentStateMachineDefinitionSnapshot(
                        definition: fixture.definition,
                        revision: 3
                    ),
                    preferredSelection: .transition(id: fixture.transitionID)
                )
            }
        )

        store.send(.updateTargetStateCreation(targetStateCreation))

        #expect(
            canvasEvents == [
                .definitionMutationWasApplied(
                    DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: fixture.definition,
                            revision: 3
                        ),
                        preferredSelection: .transition(id: fixture.transitionID)
                    ),
                    transitionPositionOverride: nil
                )
            ]
        )
    }
}

@MainActor
private func makeTransitionInspectorStore(
    transitionID: String,
    sendEditorCanvasEvent: @escaping @MainActor @Sendable (EditorCanvasStore.Event) -> Void = { _ in },
    assignSourceState: @escaping @Sendable (String, String) -> DefinitionMutationResult? = { _, _ in nil },
    assignEvent: @escaping @Sendable (String, String) -> DefinitionMutationResult? = { _, _ in nil },
    assignNewEvent: @escaping @Sendable (String, String, [PropertyDefinition]) -> DefinitionMutationResult? = { _, _, _ in nil },
    assignTargetState: @escaping @Sendable (String, String) -> DefinitionMutationResult? = { _, _ in nil },
    updateTargetStateCreation: @escaping @Sendable (String, TransitionTargetStateCreation) -> DefinitionMutationResult? = { _, _ in nil },
    assignGuard: @escaping @Sendable (String, GuardReference) -> DefinitionMutationResult? = { _, _ in nil },
    removeGuard: @escaping @Sendable (String) -> DefinitionMutationResult? = { _ in nil },
    addEffect: @escaping @Sendable (String, EffectReference) -> DefinitionMutationResult? = { _, _ in nil },
    updateEffect: @escaping @Sendable (String, Int, EffectReference) -> DefinitionMutationResult? = { _, _, _ in nil },
    removeEffect: @escaping @Sendable (String, Int) -> DefinitionMutationResult? = { _, _ in nil }
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
        sendEditorCanvasEvent: .init(send: sendEditorCanvasEvent)
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
