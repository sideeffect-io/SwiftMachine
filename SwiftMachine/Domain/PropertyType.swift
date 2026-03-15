//
//  PropertyType.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

enum PropertyType: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case string
    case integer
    case double
    case boolean
}
