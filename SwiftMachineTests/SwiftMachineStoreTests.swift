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

        guard case .designing(let stateMachine) = store.state else {
            Issue.record("Expected the store to publish the designing phase.")
            return
        }

        #expect(stateMachine.name == "Checkout")
        #expect(stateMachine.states.count == 1)
        #expect(stateMachine.states.first?.name == "Idle")
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
            initialState: .designing(stateMachine: initialMachine)
        )

        store.send(.addNewState)
        store.send(.addNewEvent)

        guard case .designing(let stateMachine) = store.state else {
            Issue.record("Expected the store to stay in the designing phase.")
            return
        }

        #expect(stateMachine.states.count == 2)
        #expect(stateMachine.states.last?.name == "State 1")
        #expect(stateMachine.events.count == 1)
        #expect(stateMachine.events.first?.name == "Event 1")
    }
}
