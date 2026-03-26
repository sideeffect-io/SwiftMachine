//
//  Transition.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct Transition<State: Sendable, Effect: Sendable>: Sendable {
    let state: State
    let effects: [Effect]
}
