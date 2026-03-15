//
//  TransitionDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct TransitionDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let sourceStateID: String
    let eventID: String
    let targetStateID: String
    let `guard`: GuardReference?
    let effects: [EffectReference]

    init(
        id: String = UUID().uuidString,
        sourceStateID: String,
        eventID: String,
        targetStateID: String,
        guard guardReference: GuardReference? = nil,
        effects: [EffectReference] = []
    ) {
        self.id = id
        self.sourceStateID = sourceStateID
        self.eventID = eventID
        self.targetStateID = targetStateID
        self.guard = guardReference
        self.effects = effects
    }
}
