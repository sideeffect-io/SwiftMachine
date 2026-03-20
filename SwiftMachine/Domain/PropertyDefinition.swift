//
//  PropertyDefinition.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct PropertyDefinition: Sendable, Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: PropertyDefaultValue?

    init(
        id: String = UUID().uuidString,
        name: String,
        type: PropertyType,
        isOptional: Bool = false,
        defaultValue: PropertyDefaultValue? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = defaultValue
    }
}
