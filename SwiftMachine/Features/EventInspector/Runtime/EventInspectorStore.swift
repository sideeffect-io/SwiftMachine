//
//  EventInspectorStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct UpdateEventNameEffectExecutor: Sendable {
    let updateEventName: @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        eventID: String,
        name: String
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateEventName(eventID, name)
    }
}

struct UpdateEventPropertiesEffectExecutor: Sendable {
    let updateEventProperties: @Sendable (String, [PropertyDefinition]) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        eventID: String,
        properties: [PropertyDefinition]
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateEventProperties(eventID, properties)
    }
}

@Observable
@MainActor
final class EventInspectorStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        let eventID: String
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case updateEventName(String)
        case updateEventProperties([PropertyDefinition])
        case selectType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case updateEventName(String)
        case updateEventProperties([PropertyDefinition])
        case selectType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let updateEventName: UpdateEventNameEffectExecutor
    private let updateEventProperties: UpdateEventPropertiesEffectExecutor
    private let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    init(
        eventID: String,
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        updateEventName: UpdateEventNameEffectExecutor,
        updateEventProperties: UpdateEventPropertiesEffectExecutor,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) {
        state = State(snapshot: .empty, eventID: eventID)
        self.observeDefinition = observeDefinition
        self.updateEventName = updateEventName
        self.updateEventProperties = updateEventProperties
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

            case .updateEventName(let name):
                guard updateEventName(eventID: state.eventID, name: name) != nil else { continue }

            case .updateEventProperties(let properties):
                guard updateEventProperties(eventID: state.eventID, properties: properties) != nil else { continue }

            case .selectType(let typeID):
                sendEditorCanvasCommand(.select(.type(id: typeID)))
            }
        }
    }
}

extension EventInspectorStore {
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

            case .updateEventName(let name):
                return .init(state: state, effects: [.updateEventName(name)])

            case .updateEventProperties(let properties):
                return .init(state: state, effects: [.updateEventProperties(properties)])

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])
            }
        }
    }
}

extension EventInspectorStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var inspectedEvent: EventDefinition? {
        definition?.events.first(where: { $0.id == state.eventID })
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types ?? []
    }
}
