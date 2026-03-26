//
//  EditorCanvasEventExecutor.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

enum EditorCanvasCommand: Sendable, Equatable {
    case select(StateMachineEditorSelection)
    case selectWhenAvailable(StateMachineEditorSelection)
    case dismissTransitionPrompt
    case positionTransitionWhenAvailable(id: String, position: StateMachineEditorPoint)
}

struct SendEditorCanvasCommandEffectExecutor: Sendable {
    let send: @MainActor @Sendable (EditorCanvasCommand) -> Void

    @MainActor
    func callAsFunction(_ command: EditorCanvasCommand) {
        send(command)
    }
}

extension EditorCanvasStore {
    @MainActor
    var sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor {
        SendEditorCanvasCommandEffectExecutor(
            send: { command in
                self.apply(command)
            }
        )
    }

    @MainActor
    func apply(_ command: EditorCanvasCommand) {
        switch command {
        case .select(let selection):
            sendSelectionEvent(for: selection)

        case .selectWhenAvailable(let selection):
            if state.snapshot.definition.map({ selection.exists(in: $0) }) == true {
                sendSelectionEvent(for: selection)
            } else {
                send(.stageSelectionWhenAvailable(selection))
            }

        case .dismissTransitionPrompt:
            send(.dismissTransitionPrompt)

        case .positionTransitionWhenAvailable(let transitionID, let position):
            if state.snapshot.definition?.transitions.contains(where: { $0.id == transitionID }) == true {
                send(.applyTransitionPositionOverride(id: transitionID, position: position))
            } else {
                send(.stageTransitionPositionWhenAvailable(id: transitionID, position: position))
            }
        }
    }

    @MainActor
    private func sendSelectionEvent(for selection: StateMachineEditorSelection) {
        switch selection {
        case .state(let stateID):
            send(.selectState(id: stateID))
        case .event(let eventID):
            send(.selectEvent(id: eventID))
        case .type(let typeID):
            send(.selectType(id: typeID))
        case .transition(let transitionID):
            send(.selectTransition(id: transitionID))
        }
    }
}
