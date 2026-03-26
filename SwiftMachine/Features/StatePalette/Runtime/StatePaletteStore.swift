//
//  StatePaletteStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct CreateStateEffectExecutor: Sendable {
    let createState: @Sendable (String, [PropertyDefinition]) -> DefinitionMutationResult?

    func callAsFunction(
        name: String,
        properties: [PropertyDefinition]
    ) -> DefinitionMutationResult? {
        createState(name, properties)
    }
}

struct DeleteStateEffectExecutor: Sendable {
    let deleteState: @Sendable (String) -> DefinitionMutationResult?

    func callAsFunction(_ stateID: String) -> DefinitionMutationResult? {
        deleteState(stateID)
    }
}

@Observable
@MainActor
final class StatePaletteStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var isObservingDefinition = false
        var isStateCreationPromptPresented = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case addStateTapped
        case cancelStateCreation
        case confirmStateCreation(name: String, properties: [PropertyDefinition])
        case selectType(id: String)
        case selectState(id: String)
        case deleteState(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case selectType(id: String)
        case selectState(id: String)
        case deleteState(id: String)
        case createState(name: String, properties: [PropertyDefinition])
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let createState: CreateStateEffectExecutor
    private let deleteState: DeleteStateEffectExecutor
    private let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    init(
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        createState: CreateStateEffectExecutor,
        deleteState: DeleteStateEffectExecutor,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) {
        state = State(snapshot: .empty)
        self.observeDefinition = observeDefinition
        self.createState = createState
        self.deleteState = deleteState
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

            case .selectType(let typeID):
                sendEditorCanvasEvent(.selectType(id: typeID))

            case .selectState(let stateID):
                sendEditorCanvasEvent(.selectState(id: stateID))

            case .deleteState(let stateID):
                guard let result = deleteState(stateID) else { continue }
                sendEditorCanvasEvent(
                    .definitionMutationWasApplied(
                        result,
                        transitionPositionOverride: nil
                    )
                )

            case .createState(let name, let properties):
                guard let result = createState(name: name, properties: properties) else { continue }
                sendEditorCanvasEvent(
                    .definitionMutationWasApplied(
                        result,
                        transitionPositionOverride: nil
                    )
                )
            }
        }
    }
}

extension StatePaletteStore {
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

            case .addStateTapped:
                state.isStateCreationPromptPresented = true
                return .init(state: state, effects: [])

            case .cancelStateCreation:
                state.isStateCreationPromptPresented = false
                return .init(state: state, effects: [])

            case .confirmStateCreation(let name, let properties):
                state.isStateCreationPromptPresented = false
                return .init(
                    state: state,
                    effects: [.createState(name: name, properties: properties)]
                )

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])

            case .selectState(let stateID):
                return .init(state: state, effects: [.selectState(id: stateID)])

            case .deleteState(let stateID):
                return .init(state: state, effects: [.deleteState(id: stateID)])
            }
        }
    }
}

extension StatePaletteStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var states: [StateDefinition] {
        definition?.states ?? []
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types ?? []
    }

    var reusableProperties: [ReusableStatePropertyOption] {
        definition?.reusableStatePropertyOptions ?? []
    }

    var suggestedStateName: String {
        definition?.nextAvailableStateName() ?? "State 1"
    }
}
