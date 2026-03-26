//
//  GuardReference.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct GuardReference: Sendable, Codable, Equatable, Hashable {
    let name: String
    let description: String?

    nonisolated init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
