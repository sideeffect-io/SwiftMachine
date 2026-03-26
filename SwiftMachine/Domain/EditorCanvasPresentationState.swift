//
//  EditorCanvasPresentationState.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct EditorCanvasPresentationState: Sendable, Equatable {
    let document: StateMachineEditorDocument
    let selection: StateMachineEditorSelection?
    let connectionDraft: StateMachineConnectionDraft?
    let transitionPrompt: StateMachineTransitionPrompt?

    init(
        definition: StateMachineDefinition,
        layout: StateMachineEditorLayout,
        selection: StateMachineEditorSelection? = nil,
        connectionDraft: StateMachineConnectionDraft? = nil,
        transitionPrompt: StateMachineTransitionPrompt? = nil
    ) {
        self.document = StateMachineEditorDocument(
            definition: definition,
            statePositions: layout.statePositions,
            transitionPositions: layout.transitionPositions
        )
        self.selection = selection
        self.connectionDraft = connectionDraft
        self.transitionPrompt = transitionPrompt
    }
}
