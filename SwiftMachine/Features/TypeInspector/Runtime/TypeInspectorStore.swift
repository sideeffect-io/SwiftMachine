//
//  TypeInspectorStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct UpdateTypeNameEffectExecutor: Sendable {
    let updateTypeName: @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        typeID: String,
        name: String
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateTypeName(typeID, name)
    }
}

struct UpdateTypeEffectExecutor: Sendable {
    let updateType: @Sendable (String, PayloadTypeDefinition) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        typeID: String,
        type: PayloadTypeDefinition
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateType(typeID, type)
    }
}

@Observable
@MainActor
final class TypeInspectorStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        let typeID: String
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case updateTypeName(String)
        case updateType(PayloadTypeDefinition)
        case selectType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case updateTypeName(String)
        case updateType(PayloadTypeDefinition)
        case selectType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let updateTypeName: UpdateTypeNameEffectExecutor
    private let updateType: UpdateTypeEffectExecutor
    private let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    init(
        typeID: String,
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        updateTypeName: UpdateTypeNameEffectExecutor,
        updateType: UpdateTypeEffectExecutor,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) {
        state = State(snapshot: .empty, typeID: typeID)
        self.observeDefinition = observeDefinition
        self.updateTypeName = updateTypeName
        self.updateType = updateType
        self.sendEditorCanvasCommand = sendEditorCanvasCommand
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

            case .updateTypeName(let name):
                guard updateTypeName(typeID: state.typeID, name: name) != nil else { continue }

            case .updateType(let type):
                guard updateType(typeID: state.typeID, type: type) != nil else { continue }

            case .selectType(let typeID):
                sendEditorCanvasCommand(.select(.type(id: typeID)))
            }
        }
    }
}

extension TypeInspectorStore {
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

            case .updateTypeName(let name):
                return .init(state: state, effects: [.updateTypeName(name)])

            case .updateType(let type):
                return .init(state: state, effects: [.updateType(type)])

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])
            }
        }
    }
}

extension TypeInspectorStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var inspectedType: PayloadTypeDefinition? {
        definition?.types.first(where: { $0.id == state.typeID })
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types.filter { $0.id != state.typeID } ?? []
    }
}
