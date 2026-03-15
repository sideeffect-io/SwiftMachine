//
//  StateMachineDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct StateMachineDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let initialStateID: String
    let states: [StateDefinition]
    let events: [EventDefinition]
    let transitions: [TransitionDefinition]

    init(
        id: String = UUID().uuidString,
        name: String,
        initialStateID: String,
        states: [StateDefinition],
        events: [EventDefinition],
        transitions: [TransitionDefinition]
    ) {
        self.id = id
        self.name = name
        self.initialStateID = initialStateID
        self.states = states
        self.events = events
        self.transitions = transitions
    }

    var isValid: Bool {
        validate().isEmpty
    }
}
