//
//  EditorCanvasStore.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Observation
import Synchronization

final class ObserveCurrentStateMachineDefinitionEffectExecutor: @unchecked Sendable {
    private struct Storage {
        var task: Task<Void, Never>?
    }

    private let observeDefinition: @Sendable () -> AsyncStream<CurrentStateMachineDefinitionSnapshot>
    private let storage = Mutex(Storage())

    init(
        observeDefinition: @escaping @Sendable () -> AsyncStream<CurrentStateMachineDefinitionSnapshot>
    ) {
        self.observeDefinition = observeDefinition
    }

    func start(
        _ onSnapshot: @escaping @MainActor @Sendable (CurrentStateMachineDefinitionSnapshot) -> Void
    ) {
        storage.withLock { storage in
            guard storage.task == nil else {
                return
            }

            storage.task = Task { [observeDefinition] in
                for await snapshot in observeDefinition() {
                    guard !Task.isCancelled else {
                        break
                    }

                    onSnapshot(snapshot)
                }
            }
        }
    }

    func cancel() {
        let task = storage.withLock { storage in
            let task = storage.task
            storage.task = nil
            return task
        }

        task?.cancel()
    }

    deinit {
        cancel()
    }
}

@Observable
@MainActor
final class EditorCanvasStore: StartableStore {
    struct State: Sendable, Equatable {
        enum Phase: Sendable, Equatable {
            case wizard
            case editing
        }

        var phase: Phase
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var layout: StateMachineEditorLayout
        var selection: StateMachineEditorSelection?
        var connectionDraft: StateMachineConnectionDraft?
        var transitionPrompt: StateMachineTransitionPrompt?
        var isObservingDefinition: Bool
        var pendingSelectionWhenAvailable: StateMachineEditorSelection?
        var pendingTransitionPositionOverrides: [String: StateMachineEditorPoint]

        static func initial() -> State {
            let snapshot = CurrentStateMachineDefinitionSnapshot.empty
            let phase: Phase = snapshot.definition == nil ? .wizard : .editing
            let layout = snapshot.definition.map(StateMachineEditorLayout.bootstrap) ?? .empty

            return State(
                phase: phase,
                snapshot: snapshot,
                layout: layout,
                selection: nil,
                connectionDraft: nil,
                transitionPrompt: nil,
                isObservingDefinition: false,
                pendingSelectionWhenAvailable: nil,
                pendingTransitionPositionOverrides: [:]
            )
        }
    }

    enum Event: Sendable, Equatable {
        case startRequested
        case snapshotDidChange(CurrentStateMachineDefinitionSnapshot)
        case stageSelectionWhenAvailable(StateMachineEditorSelection)
        case stageTransitionPositionWhenAvailable(id: String, position: StateMachineEditorPoint)
        case applyTransitionPositionOverride(id: String, position: StateMachineEditorPoint)
        case selectState(id: String)
        case selectEvent(id: String)
        case selectType(id: String)
        case selectTransition(id: String)
        case clearSelection
        case moveState(id: String, to: StateMachineEditorPoint)
        case moveTransition(id: String, to: StateMachineEditorPoint)
        case startConnectionDrag(sourceStateID: String, location: StateMachineEditorPoint)
        case updateConnectionDrag(location: StateMachineEditorPoint)
        case completeConnectionDrag(targetStateID: String?, promptLocation: StateMachineEditorPoint)
        case cancelConnectionDrag
        case dismissTransitionPrompt
    }

    enum Effect: Sendable, Equatable {
        case startObservingDefinition
    }

    private(set) var state: State

    private let observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor

    init(
        observeDefinition: ObserveCurrentStateMachineDefinitionEffectExecutor
    ) {
        state = .initial()
        self.observeDefinition = observeDefinition
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
            }
        }
    }
}

extension EditorCanvasStore {
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
                state = reconcile(state: state, snapshot: snapshot)
                return .init(state: state, effects: [])

            case .stageSelectionWhenAvailable(let selection):
                state.pendingSelectionWhenAvailable = selection
                return .init(state: state, effects: [])

            case .stageTransitionPositionWhenAvailable(let transitionID, let position):
                state.pendingTransitionPositionOverrides[transitionID] = position
                return .init(state: state, effects: [])

            case .applyTransitionPositionOverride(let transitionID, let position):
                state.layout = state.layout.movingTransition(id: transitionID, to: position)
                return .init(state: state, effects: [])

            case .selectState(let stateID):
                state.selection = .state(id: stateID)
                return .init(state: state, effects: [])

            case .selectEvent(let eventID):
                state.selection = .event(id: eventID)
                return .init(state: state, effects: [])

            case .selectType(let typeID):
                state.selection = .type(id: typeID)
                return .init(state: state, effects: [])

            case .selectTransition(let transitionID):
                state.selection = .transition(id: transitionID)
                return .init(state: state, effects: [])

            case .clearSelection:
                state.selection = nil
                return .init(state: state, effects: [])

            case .moveState(let stateID, let position):
                state.layout = state.layout.movingState(id: stateID, to: position)
                state.selection = .state(id: stateID)
                return .init(state: state, effects: [])

            case .moveTransition(let transitionID, let position):
                state.layout = state.layout.movingTransition(id: transitionID, to: position)
                state.selection = .transition(id: transitionID)
                return .init(state: state, effects: [])

            case .startConnectionDrag(let sourceStateID, let location):
                state.selection = .state(id: sourceStateID)
                state.connectionDraft = StateMachineConnectionDraft(
                    sourceStateID: sourceStateID,
                    currentLocation: location
                )
                state.transitionPrompt = nil
                return .init(state: state, effects: [])

            case .updateConnectionDrag(let location):
                guard let connectionDraft = state.connectionDraft else {
                    return .init(state: state, effects: [])
                }

                state.connectionDraft = StateMachineConnectionDraft(
                    sourceStateID: connectionDraft.sourceStateID,
                    currentLocation: location
                )
                return .init(state: state, effects: [])

            case .completeConnectionDrag(let targetStateID, let promptLocation):
                guard let connectionDraft = state.connectionDraft else {
                    return .init(state: state, effects: [])
                }

                state.connectionDraft = nil

                guard let targetStateID else {
                    state.selection = .state(id: connectionDraft.sourceStateID)
                    return .init(state: state, effects: [])
                }

                state.selection = nil
                state.transitionPrompt = StateMachineTransitionPrompt(
                    sourceStateID: connectionDraft.sourceStateID,
                    targetStateID: targetStateID,
                    anchor: promptLocation
                )
                return .init(state: state, effects: [])

            case .cancelConnectionDrag:
                state.connectionDraft = nil
                return .init(state: state, effects: [])

            case .dismissTransitionPrompt:
                state.transitionPrompt = nil
                return .init(state: state, effects: [])
            }
        }

        private static func reconcile(
            state: State,
            snapshot: CurrentStateMachineDefinitionSnapshot
        ) -> State {
            var state = state
            let previousDefinition = state.snapshot.definition
            let nextDefinition = snapshot.definition

            state.snapshot = snapshot
            state.phase = nextDefinition == nil ? .wizard : .editing

            if let nextDefinition {
                let validTransitionIDs = Set(nextDefinition.transitions.map(\.id))
                let appliedTransitionPositionOverrides = state.pendingTransitionPositionOverrides
                    .filter { validTransitionIDs.contains($0.key) }

                state.layout = state.layout.reconciled(
                    from: previousDefinition,
                    to: nextDefinition,
                    transitionPositionOverrides: appliedTransitionPositionOverrides
                )

                if let pendingSelection = state.pendingSelectionWhenAvailable,
                   pendingSelection.exists(in: nextDefinition) {
                    state.selection = pendingSelection
                    state.pendingSelectionWhenAvailable = nil
                } else {
                    state.selection = reconciledSelection(
                        state.selection,
                        in: nextDefinition
                    )
                }

                state.pendingTransitionPositionOverrides = state.pendingTransitionPositionOverrides
                    .filter { !validTransitionIDs.contains($0.key) }
                state.connectionDraft = reconciledConnectionDraft(
                    state.connectionDraft,
                    in: nextDefinition
                )
                state.transitionPrompt = reconciledTransitionPrompt(
                    state.transitionPrompt,
                    in: nextDefinition
                )
            } else {
                state.layout = .empty
                state.selection = nil
                state.connectionDraft = nil
                state.transitionPrompt = nil
                state.pendingSelectionWhenAvailable = nil
                state.pendingTransitionPositionOverrides = [:]
            }

            return state
        }

        private static func reconciledSelection(
            _ selection: StateMachineEditorSelection?,
            in definition: StateMachineDefinition
        ) -> StateMachineEditorSelection? {
            guard let selection else {
                return nil
            }

            return selection.exists(in: definition) ? selection : nil
        }

        private static func reconciledConnectionDraft(
            _ draft: StateMachineConnectionDraft?,
            in definition: StateMachineDefinition
        ) -> StateMachineConnectionDraft? {
            guard let draft else {
                return nil
            }

            guard definition.states.contains(where: { $0.id == draft.sourceStateID }) else {
                return nil
            }

            return draft
        }

        private static func reconciledTransitionPrompt(
            _ prompt: StateMachineTransitionPrompt?,
            in definition: StateMachineDefinition
        ) -> StateMachineTransitionPrompt? {
            guard let prompt else {
                return nil
            }

            guard definition.states.contains(where: { $0.id == prompt.sourceStateID }),
                  definition.states.contains(where: { $0.id == prompt.targetStateID }) else {
                return nil
            }

            return prompt
        }
    }
}

extension EditorCanvasStore {
    var isEditing: Bool {
        state.phase == .editing
    }

    var selectedStateID: String? {
        guard case .state(let stateID) = state.selection else {
            return nil
        }

        return stateID
    }

    var selectedEventID: String? {
        guard case .event(let eventID) = state.selection else {
            return nil
        }

        return eventID
    }

    var selectedTypeID: String? {
        guard case .type(let typeID) = state.selection else {
            return nil
        }

        return typeID
    }

    var selectedTransitionID: String? {
        guard case .transition(let transitionID) = state.selection else {
            return nil
        }

        return transitionID
    }

    var presentationState: EditorCanvasPresentationState? {
        guard let definition = state.snapshot.definition else {
            return nil
        }

        return EditorCanvasPresentationState(
            definition: definition,
            layout: state.layout,
            selection: state.selection,
            connectionDraft: state.connectionDraft,
            transitionPrompt: state.transitionPrompt
        )
    }
}
