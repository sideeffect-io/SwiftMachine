//
//  EditorCanvasInteractionState.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import Foundation

enum StateMachineEditorSelection: Sendable, Equatable {
    case state(id: String)
    case event(id: String)
    case type(id: String)
    case transition(id: String)

    func exists(in definition: StateMachineDefinition) -> Bool {
        switch self {
        case .state(let id):
            definition.states.contains(where: { $0.id == id })
        case .event(let id):
            definition.events.contains(where: { $0.id == id })
        case .type(let id):
            definition.types.contains(where: { $0.id == id })
        case .transition(let id):
            definition.transitions.contains(where: { $0.id == id })
        }
    }
}

struct StateMachineConnectionDraft: Sendable, Equatable {
    let sourceStateID: String
    let currentLocation: StateMachineEditorPoint
}

struct StateMachineTransitionPrompt: Sendable, Equatable {
    let sourceStateID: String
    let targetStateID: String
    let anchor: StateMachineEditorPoint
}

struct StateMachineStateCreationPrompt: Sendable, Equatable {
    let suggestedName: String
}

struct StateMachineEventCreationPrompt: Sendable, Equatable {
    let suggestedName: String
}
