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
    let targetStateCreation: TransitionTargetStateCreation
    let `guard`: GuardReference?
    let effects: [EffectReference]

    init(
        id: String = UUID().uuidString,
        sourceStateID: String,
        eventID: String,
        targetStateID: String,
        targetStateCreation: TransitionTargetStateCreation = .init(),
        guard guardReference: GuardReference? = nil,
        effects: [EffectReference] = []
    ) {
        self.id = id
        self.sourceStateID = sourceStateID
        self.eventID = eventID
        self.targetStateID = targetStateID
        self.targetStateCreation = targetStateCreation
        self.guard = guardReference
        self.effects = effects
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceStateID
        case eventID
        case targetStateID
        case targetStateCreation
        case `guard`
        case effects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceStateID = try container.decode(String.self, forKey: .sourceStateID)
        eventID = try container.decode(String.self, forKey: .eventID)
        targetStateID = try container.decode(String.self, forKey: .targetStateID)
        targetStateCreation = try container.decodeIfPresent(
            TransitionTargetStateCreation.self,
            forKey: .targetStateCreation
        ) ?? .init()
        `guard` = try container.decodeIfPresent(GuardReference.self, forKey: .guard)
        effects = try container.decodeIfPresent([EffectReference].self, forKey: .effects) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceStateID, forKey: .sourceStateID)
        try container.encode(eventID, forKey: .eventID)
        try container.encode(targetStateID, forKey: .targetStateID)
        try container.encode(targetStateCreation, forKey: .targetStateCreation)
        try container.encodeIfPresent(`guard`, forKey: .guard)
        try container.encode(effects, forKey: .effects)
    }
}
