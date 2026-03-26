//
//  StateInspectorStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct UpdateStateNameEffectExecutor: Sendable {
    let updateStateName: @Sendable (String, String) -> DefinitionMutationResult?

    func callAsFunction(
        stateID: String,
        name: String
    ) -> DefinitionMutationResult? {
        updateStateName(stateID, name)
    }
}

struct UpdateStatePropertiesEffectExecutor: Sendable {
    let updateStateProperties: @Sendable (String, [PropertyDefinition]) -> DefinitionMutationResult?

    func callAsFunction(
        stateID: String,
        properties: [PropertyDefinition]
    ) -> DefinitionMutationResult? {
        updateStateProperties(stateID, properties)
    }
}

@Observable
@MainActor
final class StateInspectorStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        let stateID: String
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case updateStateName(String)
        case updateStateProperties([PropertyDefinition])
        case selectType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case updateStateName(String)
        case updateStateProperties([PropertyDefinition])
        case selectType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let updateStateName: UpdateStateNameEffectExecutor
    private let updateStateProperties: UpdateStatePropertiesEffectExecutor
    private let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    init(
        stateID: String,
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        updateStateName: UpdateStateNameEffectExecutor,
        updateStateProperties: UpdateStatePropertiesEffectExecutor,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) {
        state = State(snapshot: .empty, stateID: stateID)
        self.observeDefinition = observeDefinition
        self.updateStateName = updateStateName
        self.updateStateProperties = updateStateProperties
        self.sendEditorCanvasEvent = sendEditorCanvasEvent
    }

    func start() {
        send(.startRequested)
    }

    func send(_ event: Event) {
        let transition = StateMachine.reduce(state, event)
        state = transition.state

        for effect in transition.effects {
            switch effect {
            case .startObservingDefinition:
                observeDefinition.start { [weak self] snapshot in
                    self?.send(.snapshotDidChange(snapshot))
                }

            case .updateStateName(let name):
                guard let result = updateStateName(stateID: state.stateID, name: name) else { continue }
                sendEditorCanvasEvent(.definitionMutationWasApplied(result, transitionPositionOverride: nil))

            case .updateStateProperties(let properties):
                guard let result = updateStateProperties(stateID: state.stateID, properties: properties) else { continue }
                sendEditorCanvasEvent(.definitionMutationWasApplied(result, transitionPositionOverride: nil))

            case .selectType(let typeID):
                sendEditorCanvasEvent(.selectType(id: typeID))
            }
        }
    }
}

extension StateInspectorStore {
    struct StateMachine {
        static func reduce(
            _ state: State,
            _ event: Event
        ) -> Transition<State, Effect> {
            var state = state

            switch event {
            case .startRequested:
                guard !state.isObservingDefinition else {
                    return .init(state: state, effects: [])
                }

                state.isObservingDefinition = true
                return .init(state: state, effects: [.startObservingDefinition])

            case .snapshotDidChange(let snapshot):
                state.snapshot = snapshot
                return .init(state: state, effects: [])

            case .updateStateName(let name):
                return .init(state: state, effects: [.updateStateName(name)])

            case .updateStateProperties(let properties):
                return .init(state: state, effects: [.updateStateProperties(properties)])

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])
            }
        }
    }
}

extension StateInspectorStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var inspectedState: StateDefinition? {
        definition?.states.first(where: { $0.id == state.stateID })
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types ?? []
    }
}
