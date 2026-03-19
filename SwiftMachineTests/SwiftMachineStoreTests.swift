//
//  SwiftMachineStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 15/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct SwiftMachineStoreTests {

    @Test("Sending wizard events publishes the phase transitions")
    func sendPublishesWizardTransitions() {
        let store = SwiftMachineStore()

        store.send(.createEmptyStateMachine(name: "Checkout"))
        #expect(store.state == .drafting(name: "Checkout"))

        store.send(
            .setInitialState(
                name: "Idle",
                properties: [PropertyDefinition(name: "amount", type: .double)]
            )
        )

        guard case .designing(let editor) = store.state else {
            Issue.record("Expected the store to publish the designing phase.")
            return
        }

        let definition = editor.document.definition

        #expect(definition.name == "Checkout")
        #expect(definition.states.count == 1)
        #expect(definition.states.first?.name == "Idle")
        #expect(editor.document.position(for: definition.initialStateID) == StateMachineEditorDocument.initialStateOrigin)
    }

    @Test("Sending editor events mutates the designing definition")
    func sendPublishesDesigningMutations() throws {
        let initialMachine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: []
            )
        )

        let store = SwiftMachineStore.make(
            initialState: .designing(editor: .bootstrap(definition: initialMachine))
        )

        store.send(.addState)
        store.send(
            .confirmStateCreation(
                name: "Loading",
                properties: [PropertyDefinition(name: "position", type: .integer)]
            )
        )
        store.send(.addEvent)
        store.send(
            .confirmEventCreation(
                name: "Submit",
                properties: [PropertyDefinition(name: "amount", type: .double)]
            )
        )

        guard case .designing(let editor) = store.state else {
            Issue.record("Expected the store to stay in the designing phase.")
            return
        }

        let definition = editor.document.definition

        #expect(definition.states.count == 2)
        #expect(definition.states.last?.name == "Loading")
        #expect(definition.states.last?.properties.map(\.name) == ["position"])
        #expect(definition.events.count == 1)
        #expect(definition.events.first?.name == "Submit")
        #expect(definition.events.first?.properties.map(\.name) == ["amount"])

        let expectedPosition = StateMachineEditorDocument.initialStateOrigin.translatingBy(
            dx: StateMachineEditorDocument.stateOriginOffset.x,
            dy: StateMachineEditorDocument.stateOriginOffset.y
        )
        let createdStateID = try #require(definition.states.last?.id)
        #expect(editor.document.position(for: createdStateID) == expectedPosition)
    }
}
