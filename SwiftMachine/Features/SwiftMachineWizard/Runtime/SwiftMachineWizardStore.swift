//
//  SwiftMachineWizardStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation
import Observation

struct CreateInitialDefinitionEffectExecutor: Sendable {
    let createInitialDefinition: @Sendable (
        String,
        String,
        [PropertyDefinition],
        [PayloadTypeDefinition]
    ) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        machineName: String,
        initialStateName: String,
        properties: [PropertyDefinition],
        types: [PayloadTypeDefinition]
    ) -> CurrentStateMachineDefinitionSnapshot? {
        createInitialDefinition(machineName, initialStateName, properties, types)
    }
}

@Observable
@MainActor
final class SwiftMachineWizardStore: StartableStore {
    struct State: Sendable, Equatable {
        var machineName: String?
    }

    enum Event: Sendable, Equatable {
        case createEmptyStateMachine(name: String)
        case setInitialState(
            initialStateName: String,
            properties: [PropertyDefinition],
            types: [PayloadTypeDefinition]
        )
    }

    enum Effect: Sendable, Equatable {
        case createInitialDefinition(
            machineName: String,
            initialStateName: String,
            properties: [PropertyDefinition],
            types: [PayloadTypeDefinition]
        )
    }

    private(set) var state = State()

    private let createInitialDefinition: CreateInitialDefinitionEffectExecutor

    init(
        createInitialDefinition: CreateInitialDefinitionEffectExecutor
    ) {
        self.createInitialDefinition = createInitialDefinition
    }

    func start() {}

    func send(_ event: Event) {
        let transition = StateMachine.reduce(state, event)
        state = transition.state

        for effect in transition.effects {
            switch effect {
            case .createInitialDefinition(let machineName, let initialStateName, let properties, let types):
                _ = createInitialDefinition(
                    machineName: machineName,
                    initialStateName: initialStateName,
                    properties: properties,
                    types: types
                )
            }
        }
    }
}

extension SwiftMachineWizardStore {
    struct StateMachine {
        static func reduce(
            _ state: State,
            _ event: Event
        ) -> Transition<State, Effect> {
            var state = state

            switch event {
            case .createEmptyStateMachine(let name):
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedName.isEmpty else {
                    return .init(state: state, effects: [])
                }

                state.machineName = trimmedName
                return .init(state: state, effects: [])

            case .setInitialState(let initialStateName, let properties, let types):
                guard let machineName = state.machineName else {
                    return .init(state: state, effects: [])
                }

                return .init(
                    state: state,
                    effects: [
                        .createInitialDefinition(
                            machineName: machineName,
                            initialStateName: initialStateName,
                            properties: properties,
                            types: types
                        )
                    ]
                )
            }
        }
    }
}
