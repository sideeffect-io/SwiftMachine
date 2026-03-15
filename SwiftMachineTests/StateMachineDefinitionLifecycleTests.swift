//
//  StateMachineDefinitionLifecycleTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 15/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct StateMachineDefinitionLifecycleTests {

    @Test("The builder creates a valid machine with one initial state")
    func builderCreatesValidInitialDefinition() throws {
        let machine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: [
                    PropertyDefinition(name: "amount", type: .double),
                    PropertyDefinition(name: "couponCode", type: .string, isOptional: true)
                ]
            )
        )

        #expect(machine.validate().isEmpty)
        #expect(machine.isValid)
        #expect(machine.name == "Checkout")
        #expect(machine.states.count == 1)
        #expect(machine.states.first?.id == machine.initialStateID)
        #expect(machine.states.first?.name == "Idle")
        #expect(machine.states.first?.properties.map(\.name) == ["amount", "couponCode"])
        #expect(machine.states.first?.properties.map(\.type) == [.double, .string])
        #expect(machine.states.first?.properties.map(\.isOptional) == [false, true])
        #expect(machine.events.isEmpty)
        #expect(machine.transitions.isEmpty)
    }

    @Test("The builder rejects duplicate initial-state property names")
    func builderRejectsDuplicatePropertyNames() {
        let machine = StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: [
                PropertyDefinition(name: "amount", type: .double),
                PropertyDefinition(name: "amount", type: .integer)
            ]
        )

        #expect(machine == nil)
    }
}
