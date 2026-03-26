//
//  EditorCanvasPresentationStateTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

struct EditorCanvasPresentationStateTests {

    @Test("Presentation state exposes a document projected from the authoritative layout")
    func documentIsProjectedFromLayout() throws {
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
        let definition = transitionResult.definition
        let layout = StateMachineEditorLayout.bootstrap(for: definition)
            .movingState(id: definition.initialStateID, to: .init(x: 420, y: 300))
            .movingTransition(id: transitionResult.transitionID, to: .init(x: 700, y: 420))

        let presentationState = EditorCanvasPresentationState(
            definition: definition,
            layout: layout,
            selection: .state(id: definition.initialStateID)
        )

        #expect(presentationState.definition == definition)
        #expect(presentationState.layout == layout)
        #expect(presentationState.document.definition == definition)
        #expect(presentationState.document.statePositions == layout.statePositions)
        #expect(presentationState.document.transitionPositions == layout.transitionPositions)
        #expect(presentationState.document.position(for: definition.initialStateID) == .init(x: 420, y: 300))
        #expect(presentationState.document.transitionPosition(for: transitionResult.transitionID) == .init(x: 700, y: 420))
    }
}
