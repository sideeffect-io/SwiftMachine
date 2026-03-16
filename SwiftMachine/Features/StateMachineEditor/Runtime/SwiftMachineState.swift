//
//  SwiftMachineState.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

enum SwiftMachineState: Sendable, Equatable {
    case empty
    case drafting(name: String)
    case designing(editor: StateMachineEditorSession)

    var isDesigning: Bool {
        if case .designing = self {
            return true
        }

        return false
    }
}
