//
//  StateMachineEditorSession.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import Foundation

struct StateMachineEditorSession: Sendable, Equatable {
    let document: StateMachineEditorDocument
    let selection: StateMachineEditorSelection?
    let connectionDraft: StateMachineConnectionDraft?
    let transitionPrompt: StateMachineTransitionPrompt?
    let stateCreationPrompt: StateMachineStateCreationPrompt?

    init(
        document: StateMachineEditorDocument,
        selection: StateMachineEditorSelection? = nil,
        connectionDraft: StateMachineConnectionDraft? = nil,
        transitionPrompt: StateMachineTransitionPrompt? = nil,
        stateCreationPrompt: StateMachineStateCreationPrompt? = nil
    ) {
        self.document = document
        self.selection = selection
        self.connectionDraft = connectionDraft
        self.transitionPrompt = transitionPrompt
        self.stateCreationPrompt = stateCreationPrompt
    }

    static func bootstrap(definition: StateMachineDefinition) -> StateMachineEditorSession {
        StateMachineEditorSession(
            document: .bootstrap(definition: definition)
        )
    }
}

enum StateMachineEditorSelection: Sendable, Equatable {
    case state(id: String)
    case transition(id: String)
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
