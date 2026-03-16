//
//  StateMachineEditorGeometry.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import Foundation

struct StateMachineEditorPoint: Sendable, Codable, Equatable, Hashable {
    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func translatingBy(dx: Double, dy: Double) -> StateMachineEditorPoint {
        StateMachineEditorPoint(x: x + dx, y: y + dy)
    }
}

struct StateMachineEditorSize: Sendable, Codable, Equatable, Hashable {
    let width: Double
    let height: Double
}

struct StateMachineEditorRect: Sendable, Codable, Equatable, Hashable {
    let origin: StateMachineEditorPoint
    let size: StateMachineEditorSize

    var minX: Double { origin.x }
    var minY: Double { origin.y }
    var maxX: Double { origin.x + size.width }
    var maxY: Double { origin.y + size.height }
    var midX: Double { origin.x + (size.width / 2) }
    var midY: Double { origin.y + (size.height / 2) }

    func contains(_ point: StateMachineEditorPoint) -> Bool {
        point.x >= minX &&
        point.x <= maxX &&
        point.y >= minY &&
        point.y <= maxY
    }
}
