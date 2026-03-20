//
//  TransitionTargetStateCreation.swift
//  SwiftMachine
//
//  Created by Codex on 17/03/2026.
//

import Foundation

struct TransitionTargetStateCreation: Sendable, Codable, Equatable, Hashable {
    let assignments: [TransitionTargetStatePropertyAssignment]

    init(assignments: [TransitionTargetStatePropertyAssignment] = []) {
        self.assignments = assignments
    }

    var isEmpty: Bool {
        assignments.isEmpty
    }
}

struct TransitionTargetStatePropertyAssignment: Sendable, Codable, Equatable, Hashable, Identifiable {
    let targetPropertyID: String
    let valueSource: TransitionTargetStateValueSource

    init(
        targetPropertyID: String,
        valueSource: TransitionTargetStateValueSource
    ) {
        self.targetPropertyID = targetPropertyID
        self.valueSource = valueSource
    }

    var id: String {
        targetPropertyID
    }
}

struct TransitionTargetStateFieldAssignment: Sendable, Codable, Equatable, Hashable, Identifiable {
    let fieldID: String
    let valueSource: TransitionTargetStateValueSource

    init(
        fieldID: String,
        valueSource: TransitionTargetStateValueSource
    ) {
        self.fieldID = fieldID
        self.valueSource = valueSource
    }

    var id: String {
        fieldID
    }
}

indirect enum TransitionTargetStateValueSource: Sendable, Codable, Equatable, Hashable {
    case targetDefault
    case sourceStateProperty(reference: PropertyValueReference)
    case eventProperty(reference: PropertyValueReference)
    case literal(LiteralValue)
    case custom(comment: String)
    case fieldMap(fields: [TransitionTargetStateFieldAssignment])
    case enumCase(caseID: String, payload: TransitionTargetStateValueSource?)
}
