//
//  StateMachineEditorLayoutTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

struct StateMachineEditorLayoutTests {

    @Test("Bootstrapping seeds deterministic positions for known states")
    func bootstrapSeedsDeterministicPositions() throws {
        let initialDefinition = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: []
            )
        )
        let secondStateResult = try #require(
            initialDefinition.addingState(
                named: "Review",
                properties: []
            )
        )

        let layout = StateMachineEditorLayout.bootstrap(for: secondStateResult.definition)

        #expect(layout.position(for: initialDefinition.initialStateID) == .init(x: 360, y: 240))
        #expect(
            layout.position(for: secondStateResult.stateID) ==
            StateMachineEditorPoint(x: 540, y: 360)
        )
    }

    @Test("Reconciling preserves known positions, adds missing state positions, and applies transition overrides")
    func reconcilePreservesAndExtendsLayout() throws {
        let initialDefinition = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: []
            )
        )
        let baseLayout = StateMachineEditorLayout.bootstrap(for: initialDefinition)
            .movingState(id: initialDefinition.initialStateID, to: .init(x: 420, y: 320))

        let secondStateResult = try #require(
            initialDefinition.addingState(
                named: "Review",
                properties: []
            )
        )
        let eventResult = try #require(
            secondStateResult.definition.addingEvent(
                named: "Advance",
                properties: []
            )
        )
        let transitionResult = try #require(
            eventResult.definition.addingTransition(
                sourceStateID: eventResult.definition.initialStateID,
                eventID: eventResult.eventID,
                targetStateID: secondStateResult.stateID
            )
        )

        let reconciled = baseLayout.reconciled(
            from: initialDefinition,
            to: transitionResult.definition,
            transitionPositionOverrides: [
                transitionResult.transitionID: .init(x: 720, y: 480)
            ]
        )

        #expect(reconciled.position(for: initialDefinition.initialStateID) == .init(x: 420, y: 320))
        #expect(reconciled.position(for: secondStateResult.stateID) == .init(x: 600, y: 440))
        #expect(reconciled.transitionPosition(for: transitionResult.transitionID) == .init(x: 720, y: 480))
    }
}
