//
//  EditorCanvasPresentationState.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct EditorCanvasPresentationState: Sendable, Equatable {
    let definition: StateMachineDefinition
    let layout: StateMachineEditorLayout
    let selection: StateMachineEditorSelection?
    let connectionDraft: StateMachineConnectionDraft?
    let transitionPrompt: StateMachineTransitionPrompt?

    var document: StateMachineEditorDocument {
        StateMachineEditorDocument(
            definition: definition,
            layout: layout
        )
    }

    init(
        definition: StateMachineDefinition,
        layout: StateMachineEditorLayout,
        selection: StateMachineEditorSelection? = nil,
        connectionDraft: StateMachineConnectionDraft? = nil,
        transitionPrompt: StateMachineTransitionPrompt? = nil
    ) {
        self.definition = definition
        self.layout = layout
        self.selection = selection
        self.connectionDraft = connectionDraft
        self.transitionPrompt = transitionPrompt
    }
}
