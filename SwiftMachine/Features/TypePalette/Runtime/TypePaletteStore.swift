//
//  TypePaletteStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct CreateStructTypeEffectExecutor: Sendable {
    let createStructType: @Sendable () -> DefinitionMutationResult?

    func callAsFunction() -> DefinitionMutationResult? {
        createStructType()
    }
}

struct CreateEnumTypeEffectExecutor: Sendable {
    let createEnumType: @Sendable () -> DefinitionMutationResult?

    func callAsFunction() -> DefinitionMutationResult? {
        createEnumType()
    }
}

struct DeleteTypeEffectExecutor: Sendable {
    let deleteType: @Sendable (String) -> DefinitionMutationResult?

    func callAsFunction(_ typeID: String) -> DefinitionMutationResult? {
        deleteType(typeID)
    }
}

@Observable
@MainActor
final class TypePaletteStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case addStructTypeTapped
        case addEnumTypeTapped
        case selectType(id: String)
        case deleteType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case createStructType
        case createEnumType
        case selectType(id: String)
        case deleteType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let createStructType: CreateStructTypeEffectExecutor
    private let createEnumType: CreateEnumTypeEffectExecutor
    private let deleteType: DeleteTypeEffectExecutor
    private let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    init(
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        createStructType: CreateStructTypeEffectExecutor,
        createEnumType: CreateEnumTypeEffectExecutor,
        deleteType: DeleteTypeEffectExecutor,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) {
        state = State(snapshot: .empty)
        self.observeDefinition = observeDefinition
        self.createStructType = createStructType
        self.createEnumType = createEnumType
        self.deleteType = deleteType
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

            case .createStructType:
                guard let result = createStructType() else { continue }
                sendEditorCanvasEvent(
                    .definitionMutationWasApplied(
                        result,
                        transitionPositionOverride: nil
                    )
                )

            case .createEnumType:
                guard let result = createEnumType() else { continue }
                sendEditorCanvasEvent(
                    .definitionMutationWasApplied(
                        result,
                        transitionPositionOverride: nil
                    )
                )

            case .selectType(let typeID):
                sendEditorCanvasEvent(.selectType(id: typeID))

            case .deleteType(let typeID):
                guard let result = deleteType(typeID) else { continue }
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

extension TypePaletteStore {
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

            case .addStructTypeTapped:
                return .init(state: state, effects: [.createStructType])

            case .addEnumTypeTapped:
                return .init(state: state, effects: [.createEnumType])

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])

            case .deleteType(let typeID):
                return .init(state: state, effects: [.deleteType(id: typeID)])
            }
        }
    }
}

extension TypePaletteStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var types: [PayloadTypeDefinition] {
        definition?.types ?? []
    }
}
