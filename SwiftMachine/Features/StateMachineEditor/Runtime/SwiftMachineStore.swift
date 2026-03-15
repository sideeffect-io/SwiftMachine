//
//  SwiftMachineStore.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Observation

@Observable
final class SwiftMachineStore {
    private(set) var state: SwiftMachineState = .empty

    func send(_ event: SwiftMachineEvent) {
        let transition = SwiftMachineStateMachine.reduce(state, event)
        state = transition.state
    }
}

extension SwiftMachineStore {
    static func make(initialState: SwiftMachineState) -> SwiftMachineStore {
        let store = SwiftMachineStore()
        store.state = initialState
        return store
    }
}
