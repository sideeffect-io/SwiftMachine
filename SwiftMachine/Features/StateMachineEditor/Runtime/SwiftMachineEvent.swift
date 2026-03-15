//
//  SwiftMachineEvent.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

enum SwiftMachineEvent: Sendable, Equatable {
    case createEmptyStateMachine(name: String)
    case setInitialState(name: String, properties: [PropertyDefinition])
    case addNewState
    case addNewEvent
    case addNewTransition
}
