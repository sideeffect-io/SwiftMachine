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
    let types: [PayloadTypeDefinition]
    let states: [StateDefinition]
    let events: [EventDefinition]
    let transitions: [TransitionDefinition]

    init(
        id: String = UUID().uuidString,
        name: String,
        initialStateID: String,
        types: [PayloadTypeDefinition] = [],
        states: [StateDefinition],
        events: [EventDefinition],
        transitions: [TransitionDefinition]
    ) {
        self.id = id
        self.name = name
        self.initialStateID = initialStateID
        self.types = types
        self.states = states
        self.events = events
        self.transitions = transitions
    }

    var isValid: Bool {
        validate().isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case initialStateID
        case types
        case states
        case events
        case transitions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        initialStateID = try container.decode(String.self, forKey: .initialStateID)
        types = try container.decodeIfPresent([PayloadTypeDefinition].self, forKey: .types) ?? []
        states = try container.decode([StateDefinition].self, forKey: .states)
        events = try container.decode([EventDefinition].self, forKey: .events)
        transitions = try container.decode([TransitionDefinition].self, forKey: .transitions)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(initialStateID, forKey: .initialStateID)
        try container.encode(types, forKey: .types)
        try container.encode(states, forKey: .states)
        try container.encode(events, forKey: .events)
        try container.encode(transitions, forKey: .transitions)
    }
}
