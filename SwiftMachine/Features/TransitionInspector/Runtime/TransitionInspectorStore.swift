//
//  TransitionInspectorStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation

struct AssignTransitionSourceStateEffectExecutor: Sendable {
    let assignSourceState: @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        stateID: String
    ) -> CurrentStateMachineDefinitionSnapshot? {
        assignSourceState(transitionID, stateID)
    }
}

struct AssignTransitionEventEffectExecutor: Sendable {
    let assignEvent: @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        eventID: String
    ) -> CurrentStateMachineDefinitionSnapshot? {
        assignEvent(transitionID, eventID)
    }
}

struct AssignNewTransitionEventEffectExecutor: Sendable {
    let assignNewEvent: @Sendable (String, String, [PropertyDefinition]) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        name: String,
        properties: [PropertyDefinition]
    ) -> CurrentStateMachineDefinitionSnapshot? {
        assignNewEvent(transitionID, name, properties)
    }
}

struct AssignTransitionTargetStateEffectExecutor: Sendable {
    let assignTargetState: @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        stateID: String
    ) -> CurrentStateMachineDefinitionSnapshot? {
        assignTargetState(transitionID, stateID)
    }
}

struct UpdateTransitionTargetStateCreationEffectExecutor: Sendable {
    let updateTargetStateCreation: @Sendable (String, TransitionTargetStateCreation) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        targetStateCreation: TransitionTargetStateCreation
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateTargetStateCreation(transitionID, targetStateCreation)
    }
}

struct AssignTransitionGuardEffectExecutor: Sendable {
    let assignGuard: @Sendable (String, GuardReference) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        guardReference: GuardReference
    ) -> CurrentStateMachineDefinitionSnapshot? {
        assignGuard(transitionID, guardReference)
    }
}

struct RemoveTransitionGuardEffectExecutor: Sendable {
    let removeGuard: @Sendable (String) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(transitionID: String) -> CurrentStateMachineDefinitionSnapshot? {
        removeGuard(transitionID)
    }
}

struct AddTransitionEffectEffectExecutor: Sendable {
    let addEffect: @Sendable (String, EffectReference) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        effect: EffectReference
    ) -> CurrentStateMachineDefinitionSnapshot? {
        addEffect(transitionID, effect)
    }
}

struct UpdateTransitionEffectAtIndexEffectExecutor: Sendable {
    let updateEffect: @Sendable (String, Int, EffectReference) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        index: Int,
        effect: EffectReference
    ) -> CurrentStateMachineDefinitionSnapshot? {
        updateEffect(transitionID, index, effect)
    }
}

struct RemoveTransitionEffectAtIndexEffectExecutor: Sendable {
    let removeEffect: @Sendable (String, Int) -> CurrentStateMachineDefinitionSnapshot?

    func callAsFunction(
        transitionID: String,
        index: Int
    ) -> CurrentStateMachineDefinitionSnapshot? {
        removeEffect(transitionID, index)
    }
}

@Observable
@MainActor
final class TransitionInspectorStore: StartableStore {
    struct State: Sendable, Equatable {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        let transitionID: String
        var isObservingDefinition = false
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case assignSourceState(String)
        case assignEvent(String)
        case assignNewEvent(name: String, properties: [PropertyDefinition])
        case assignTargetState(String)
        case updateTargetStateCreation(TransitionTargetStateCreation)
        case assignGuard(GuardReference)
        case removeGuard
        case addEffect(EffectReference)
        case updateEffect(index: Int, effect: EffectReference)
        case removeEffect(index: Int)
        case selectType(id: String)
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
        case assignSourceState(String)
        case assignEvent(String)
        case assignNewEvent(name: String, properties: [PropertyDefinition])
        case assignTargetState(String)
        case updateTargetStateCreation(TransitionTargetStateCreation)
        case assignGuard(GuardReference)
        case removeGuard
        case addEffect(EffectReference)
        case updateEffect(index: Int, effect: EffectReference)
        case removeEffect(index: Int)
        case selectType(id: String)
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    private let assignSourceState: AssignTransitionSourceStateEffectExecutor
    private let assignEvent: AssignTransitionEventEffectExecutor
    private let assignNewEvent: AssignNewTransitionEventEffectExecutor
    private let assignTargetState: AssignTransitionTargetStateEffectExecutor
    private let updateTargetStateCreation: UpdateTransitionTargetStateCreationEffectExecutor
    private let assignGuard: AssignTransitionGuardEffectExecutor
    private let removeGuard: RemoveTransitionGuardEffectExecutor
    private let addEffect: AddTransitionEffectEffectExecutor
    private let updateEffect: UpdateTransitionEffectAtIndexEffectExecutor
    private let removeEffect: RemoveTransitionEffectAtIndexEffectExecutor
    private let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    init(
        transitionID: String,
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor,
        assignSourceState: AssignTransitionSourceStateEffectExecutor,
        assignEvent: AssignTransitionEventEffectExecutor,
        assignNewEvent: AssignNewTransitionEventEffectExecutor,
        assignTargetState: AssignTransitionTargetStateEffectExecutor,
        updateTargetStateCreation: UpdateTransitionTargetStateCreationEffectExecutor,
        assignGuard: AssignTransitionGuardEffectExecutor,
        removeGuard: RemoveTransitionGuardEffectExecutor,
        addEffect: AddTransitionEffectEffectExecutor,
        updateEffect: UpdateTransitionEffectAtIndexEffectExecutor,
        removeEffect: RemoveTransitionEffectAtIndexEffectExecutor,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) {
        state = State(snapshot: .empty, transitionID: transitionID)
        self.observeDefinition = observeDefinition
        self.assignSourceState = assignSourceState
        self.assignEvent = assignEvent
        self.assignNewEvent = assignNewEvent
        self.assignTargetState = assignTargetState
        self.updateTargetStateCreation = updateTargetStateCreation
        self.assignGuard = assignGuard
        self.removeGuard = removeGuard
        self.addEffect = addEffect
        self.updateEffect = updateEffect
        self.removeEffect = removeEffect
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

            case .assignSourceState(let stateID):
                guard assignSourceState(
                    transitionID: state.transitionID,
                    stateID: stateID
                ) != nil else { continue }

            case .assignEvent(let eventID):
                guard assignEvent(
                    transitionID: state.transitionID,
                    eventID: eventID
                ) != nil else { continue }

            case .assignNewEvent(let name, let properties):
                guard assignNewEvent(
                    transitionID: state.transitionID,
                    name: name,
                    properties: properties
                ) != nil else { continue }

            case .assignTargetState(let stateID):
                guard assignTargetState(
                    transitionID: state.transitionID,
                    stateID: stateID
                ) != nil else { continue }

            case .updateTargetStateCreation(let targetStateCreation):
                guard updateTargetStateCreation(
                    transitionID: state.transitionID,
                    targetStateCreation: targetStateCreation
                ) != nil else { continue }

            case .assignGuard(let guardReference):
                guard assignGuard(
                    transitionID: state.transitionID,
                    guardReference: guardReference
                ) != nil else { continue }

            case .removeGuard:
                guard removeGuard(transitionID: state.transitionID) != nil else { continue }

            case .addEffect(let effect):
                guard addEffect(
                    transitionID: state.transitionID,
                    effect: effect
                ) != nil else { continue }

            case .updateEffect(let index, let effect):
                guard updateEffect(
                    transitionID: state.transitionID,
                    index: index,
                    effect: effect
                ) != nil else { continue }

            case .removeEffect(let index):
                guard removeEffect(
                    transitionID: state.transitionID,
                    index: index
                ) != nil else { continue }

            case .selectType(let typeID):
                sendEditorCanvasCommand(.select(.type(id: typeID)))
            }
        }
    }
}

extension TransitionInspectorStore {
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

            case .assignSourceState(let stateID):
                return .init(state: state, effects: [.assignSourceState(stateID)])

            case .assignEvent(let eventID):
                return .init(state: state, effects: [.assignEvent(eventID)])

            case .assignNewEvent(let name, let properties):
                return .init(state: state, effects: [.assignNewEvent(name: name, properties: properties)])

            case .assignTargetState(let stateID):
                return .init(state: state, effects: [.assignTargetState(stateID)])

            case .updateTargetStateCreation(let targetStateCreation):
                return .init(state: state, effects: [.updateTargetStateCreation(targetStateCreation)])

            case .assignGuard(let guardReference):
                return .init(state: state, effects: [.assignGuard(guardReference)])

            case .removeGuard:
                return .init(state: state, effects: [.removeGuard])

            case .addEffect(let effect):
                return .init(state: state, effects: [.addEffect(effect)])

            case .updateEffect(let index, let effect):
                return .init(state: state, effects: [.updateEffect(index: index, effect: effect)])

            case .removeEffect(let index):
                return .init(state: state, effects: [.removeEffect(index: index)])

            case .selectType(let typeID):
                return .init(state: state, effects: [.selectType(id: typeID)])
            }
        }
    }
}

extension TransitionInspectorStore {
    var definition: StateMachineDefinition? {
        state.snapshot.definition
    }

    var inspectedTransition: TransitionDefinition? {
        definition?.transitions.first(where: { $0.id == state.transitionID })
    }
}
