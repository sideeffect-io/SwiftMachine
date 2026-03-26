//
//  EventPaletteStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct CreateEventEffectExecutor: Sendable {
    let createEvent: @Sendable (String, [PropertyDefinition]) -> DefinitionMutationResult?

    func callAsFunction(
        name: String,
        properties: [PropertyDefinition]
    ) -> DefinitionMutationResult? {
        createEvent(name, properties)
    }
}

struct DeleteEventEffectExecutor: Sendable {
    let deleteEvent: @Sendable (String) -> DefinitionMutationResult?

    func callAsFunction(_ eventID: String) -> DefinitionMutationResult? {
        deleteEvent(eventID)
    }
}

@Observable
@MainActor
final class EventPaletteStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var isObservingDefinition = false
        var isEventCreationPromptPresented = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case addEventTapped
        case cancelEventCreation
        case confirmEventCreation(name: String, properties: [PropertyDefinition])
        case selectType(id: String)
        case selectEvent(id: String)
        case deleteEvent(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case selectType(id: String)
        case selectEvent(id: String)
        case deleteEvent(id: String)
        case createEvent(name: String, properties: [PropertyDefinition])
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let createEvent: CreateEventEffectExecutor
    private let deleteEvent: DeleteEventEffectExecutor
    private let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    init(
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        createEvent: CreateEventEffectExecutor,
        deleteEvent: DeleteEventEffectExecutor,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) {
        state = State(snapshot: .empty)
        self.observeDefinition = observeDefinition
        self.createEvent = createEvent
        self.deleteEvent = deleteEvent
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

            case .selectEvent(let eventID):
                sendEditorCanvasEvent(.selectEvent(id: eventID))

            case .deleteEvent(let eventID):
                guard let result = deleteEvent(eventID) else { continue }
                sendEditorCanvasEvent(
                    .definitionMutationWasApplied(
                        result,
                        transitionPositionOverride: nil
                    )
                )

            case .createEvent(let name, let properties):
                guard let result = createEvent(name: name, properties: properties) else { continue }
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

extension EventPaletteStore {
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

            case .addEventTapped:
                state.isEventCreationPromptPresented = true
                return .init(state: state, effects: [])

            case .cancelEventCreation:
                state.isEventCreationPromptPresented = false
                return .init(state: state, effects: [])

            case .confirmEventCreation(let name, let properties):
                state.isEventCreationPromptPresented = false
                return .init(
                    state: state,
                    effects: [.createEvent(name: name, properties: properties)]
                )

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])

            case .selectEvent(let eventID):
                return .init(state: state, effects: [.selectEvent(id: eventID)])

            case .deleteEvent(let eventID):
                return .init(state: state, effects: [.deleteEvent(id: eventID)])
            }
        }
    }
}

extension EventPaletteStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var events: [EventDefinition] {
        definition?.events ?? []
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types ?? []
    }

    var suggestedEventName: String {
        definition?.nextAvailableEventName() ?? "Event 1"
    }
}
