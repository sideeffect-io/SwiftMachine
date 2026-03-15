//
//  SwiftMachineStateMachine.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct Transition<State: Sendable, Effect: Sendable>: Sendable {
    let state: State
    let effects: [Effect]
}

enum SwiftMachineStateMachine {
    static func reduce(
        _ phase: SwiftMachineState,
        _ event: SwiftMachineEvent
    ) -> Transition<SwiftMachineState, SwiftMachineEffect> {
        switch (phase, event) {
        case (.empty, .createEmptyStateMachine(let name)):
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedName.isEmpty else {
                return .init(state: .empty, effects: [])
            }

            return .init(state: .drafting(name: trimmedName), effects: [])

        case (.drafting(let machineName), .setInitialState(let stateName, let properties)):
            guard let stateMachine = StateMachineDefinition.makeNew(
                name: machineName,
                initialStateName: stateName,
                initialStateProperties: properties
            ) else {
                return .init(state: .drafting(name: machineName), effects: [])
            }

            return .init(state: .designing(stateMachine: stateMachine), effects: [])

        case (.designing(let stateMachine), .addNewState):
            return .init(
                state: .designing(stateMachine: stateMachine.addingState()),
                effects: []
            )

        case (.designing(let stateMachine), .addNewEvent):
            return .init(
                state: .designing(stateMachine: stateMachine.addingEvent()),
                effects: []
            )

        case (.designing(let stateMachine), .addNewTransition):
            return .init(
                state: .designing(stateMachine: stateMachine),
                effects: []
            )

        default:
            return .init(state: phase, effects: [])
        }
    }
}
