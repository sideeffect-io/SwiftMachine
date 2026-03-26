//
//  SwiftMachineWizardStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct SwiftMachineWizardStoreTests {

    @Test("Creating an empty machine stores the trimmed machine name locally")
    func createEmptyMachineStoresTrimmedName() {
        let store = SwiftMachineWizardStore(
            createInitialDefinition: .init(
                createInitialDefinition: { _, _, _, _ in
                    Issue.record("The creation executor should not run during the first wizard step.")
                    return nil
                }
            )
        )

        store.send(.createEmptyStateMachine(name: "  Checkout  "))

        #expect(store.state.machineName == "Checkout")
    }

    @Test("Submitting the initial state delegates to the creation executor with the stored machine name")
    func setInitialStateInvokesExecutor() throws {
        var capturedInvocation: (String, String, [PropertyDefinition], [PayloadTypeDefinition])?
        let createdDefinition = try makeWizardDefinition()

        let store = SwiftMachineWizardStore(
            createInitialDefinition: .init(
                createInitialDefinition: { machineName, initialStateName, properties, types in
                    capturedInvocation = (machineName, initialStateName, properties, types)
                    return CurrentStateMachineDefinitionSnapshot(
                        definition: createdDefinition,
                        revision: 1
                    )
                }
            )
        )

        let properties = [PropertyDefinition(name: "amount", type: .double)]
        let types = [PayloadTypeDefinition(id: "money", name: "Money", kind: .structType(fields: []))]

        store.send(.createEmptyStateMachine(name: "Checkout"))
        store.send(
            .setInitialState(
                initialStateName: "Idle",
                properties: properties,
                types: types
            )
        )

        let invocation = try #require(capturedInvocation)
        #expect(invocation.0 == "Checkout")
        #expect(invocation.1 == "Idle")
        #expect(invocation.2 == properties)
        #expect(invocation.3 == types)
    }
}

private func makeWizardDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
