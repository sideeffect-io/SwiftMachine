//
//  SwiftMachineStateMachineTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 15/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct SwiftMachineStateMachineTests {

    @Test("The initial editor phase is empty")
    func initialPhaseIsEmpty() {
        #expect(SwiftMachineStore().state == .empty)
    }

    @Test("A blank machine name keeps the editor in the empty phase")
    func blankMachineNameDoesNotAdvance() {
        let transition = SwiftMachineStateMachine.reduce(
            .empty,
            .createEmptyStateMachine(name: "   ")
        )

        #expect(transition.state == .empty)
        #expect(transition.effects.isEmpty)
    }

    @Test("A valid machine name moves the editor to the drafted phase")
    func validMachineNameCreatesDraftedPhase() {
        let transition = SwiftMachineStateMachine.reduce(
            .empty,
            .createEmptyStateMachine(name: " Checkout ")
        )

        #expect(transition.state == .drafting(name: "Checkout"))
        #expect(transition.effects.isEmpty)
    }

    @Test("A blank initial state name keeps the editor in the drafted phase")
    func blankInitialStateNameDoesNotAdvance() {
        let transition = SwiftMachineStateMachine.reduce(
            .drafting(name: "Checkout"),
            .setInitialState(name: " ", properties: [])
        )

        #expect(transition.state == .drafting(name: "Checkout"))
        #expect(transition.effects.isEmpty)
    }

    @Test("A valid initial state creates the designing phase")
    func validInitialStateCreatesDesigningPhase() {
        let transition = SwiftMachineStateMachine.reduce(
            .drafting(name: "Checkout"),
            .setInitialState(
                name: "Idle",
                properties: [PropertyDefinition(name: "amount", type: .double)]
            )
        )

        guard case .designing(let stateMachine) = transition.state else {
            Issue.record("Expected the reducer to enter the designing phase.")
            return
        }

        guard let initialState = stateMachine.states.first else {
            Issue.record("Expected the created machine to include an initial state.")
            return
        }

        #expect(transition.effects.isEmpty)
        #expect(stateMachine.name == "Checkout")
        #expect(stateMachine.initialStateID == initialState.id)
        #expect(initialState.properties.map(\.name) == ["amount"])
        #expect(initialState.properties.map(\.type) == [.double])
        #expect(stateMachine.isValid)
    }
}
