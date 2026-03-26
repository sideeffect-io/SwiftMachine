//
//  TransitionComposerStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct CreateTransitionWithExistingEventEffectExecutor: Sendable {
    let createTransition: @Sendable (
        StateMachineTransitionPrompt,
        String,
        [PropertyDefinition],
        TransitionTargetStateCreation
    ) -> String?

    func callAsFunction(
        prompt: StateMachineTransitionPrompt,
        eventID: String,
        properties: [PropertyDefinition],
        targetStateCreation: TransitionTargetStateCreation
    ) -> String? {
        createTransition(prompt, eventID, properties, targetStateCreation)
    }
}

struct CreateTransitionWithNewEventEffectExecutor: Sendable {
    let createTransition: @Sendable (
        StateMachineTransitionPrompt,
        String,
        [PropertyDefinition],
        TransitionTargetStateCreation
    ) -> String?

    func callAsFunction(
        prompt: StateMachineTransitionPrompt,
        name: String,
        properties: [PropertyDefinition],
        targetStateCreation: TransitionTargetStateCreation
    ) -> String? {
        createTransition(prompt, name, properties, targetStateCreation)
    }
}

@Observable
@MainActor
final class TransitionComposerStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        let prompt: StateMachineTransitionPrompt
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case cancelRequested
        case confirmWithExistingEvent(
            eventID: String,
            properties: [PropertyDefinition],
            targetStateCreation: TransitionTargetStateCreation
        )
        case confirmWithNewEvent(
            name: String,
            properties: [PropertyDefinition],
            targetStateCreation: TransitionTargetStateCreation
        )
        case selectType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case dismissPrompt
        case createWithExistingEvent(
            eventID: String,
            properties: [PropertyDefinition],
            targetStateCreation: TransitionTargetStateCreation
        )
        case createWithNewEvent(
            name: String,
            properties: [PropertyDefinition],
            targetStateCreation: TransitionTargetStateCreation
        )
        case selectType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let createWithExistingEvent: CreateTransitionWithExistingEventEffectExecutor
    private let createWithNewEvent: CreateTransitionWithNewEventEffectExecutor
    private let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    init(
        prompt: StateMachineTransitionPrompt,
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        createWithExistingEvent: CreateTransitionWithExistingEventEffectExecutor,
        createWithNewEvent: CreateTransitionWithNewEventEffectExecutor,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) {
        state = State(snapshot: .empty, prompt: prompt)
        self.observeDefinition = observeDefinition
        self.createWithExistingEvent = createWithExistingEvent
        self.createWithNewEvent = createWithNewEvent
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

            case .dismissPrompt:
                sendEditorCanvasCommand(.dismissTransitionPrompt)

            case .createWithExistingEvent(let eventID, let properties, let targetStateCreation):
                guard let transitionID = createWithExistingEvent(
                    prompt: state.prompt,
                    eventID: eventID,
                    properties: properties,
                    targetStateCreation: targetStateCreation
                ) else {
                    continue
                }
                sendEditorCanvasCommand(.selectWhenAvailable(.transition(id: transitionID)))
                sendEditorCanvasCommand(
                    .positionTransitionWhenAvailable(
                        id: transitionID,
                        position: state.prompt.anchor
                    )
                )
                sendEditorCanvasCommand(.dismissTransitionPrompt)

            case .createWithNewEvent(let name, let properties, let targetStateCreation):
                guard let transitionID = createWithNewEvent(
                    prompt: state.prompt,
                    name: name,
                    properties: properties,
                    targetStateCreation: targetStateCreation
                ) else {
                    continue
                }
                sendEditorCanvasCommand(.selectWhenAvailable(.transition(id: transitionID)))
                sendEditorCanvasCommand(
                    .positionTransitionWhenAvailable(
                        id: transitionID,
                        position: state.prompt.anchor
                    )
                )
                sendEditorCanvasCommand(.dismissTransitionPrompt)

            case .selectType(let typeID):
                sendEditorCanvasCommand(.select(.type(id: typeID)))
            }
        }
    }
}

extension TransitionComposerStore {
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

            case .cancelRequested:
                return .init(state: state, effects: [.dismissPrompt])

            case .confirmWithExistingEvent(let eventID, let properties, let targetStateCreation):
                return .init(
                    state: state,
                    effects: [
                        .createWithExistingEvent(
                            eventID: eventID,
                            properties: properties,
                            targetStateCreation: targetStateCreation
                        )
                    ]
                )

            case .confirmWithNewEvent(let name, let properties, let targetStateCreation):
                return .init(
                    state: state,
                    effects: [
                        .createWithNewEvent(
                            name: name,
                            properties: properties,
                            targetStateCreation: targetStateCreation
                        )
                    ]
                )

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])
            }
        }
    }
}

extension TransitionComposerStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var availableModelTypes: [PayloadTypeDefinition] {
        definition?.types ?? []
    }
}
