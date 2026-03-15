//
//  StateDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct StateDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let properties: [PropertyDefinition]

    init(
        id: String = UUID().uuidString,
        name: String,
        properties: [PropertyDefinition] = []
    ) {
        self.id = id
        self.name = name
        self.properties = properties
    }
}
