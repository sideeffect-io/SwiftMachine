//
//  SwiftMachineEvent.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

enum SwiftMachineEvent: Sendable, Equatable {
    case createEmptyStateMachine(name: String)
    case setInitialState(name: String, properties: [PropertyDefinition])
    case addState
    case confirmStateCreation(name: String, properties: [PropertyDefinition])
    case cancelStateCreation
    case addEvent
    case updateStateName(stateID: String, name: String)
    case updateStateProperties(stateID: String, properties: [PropertyDefinition])
    case selectState(id: String)
    case selectTransition(id: String)
    case clearSelection
    case moveState(id: String, to: StateMachineEditorPoint)
    case startConnectionDrag(sourceStateID: String, location: StateMachineEditorPoint)
    case updateConnectionDrag(location: StateMachineEditorPoint)
    case completeConnectionDrag(targetStateID: String?, promptLocation: StateMachineEditorPoint)
    case cancelConnectionDrag
    case confirmTransitionPromptWithExistingEvent(eventID: String)
    case confirmTransitionPromptWithNewEvent(name: String)
    case cancelTransitionPrompt
    case assignSourceStateToTransition(transitionID: String, sourceStateID: String)
    case assignEventToTransition(transitionID: String, eventID: String)
    case assignNewEventToTransition(transitionID: String, name: String)
    case assignTargetStateToTransition(transitionID: String, targetStateID: String)
    case assignGuardToTransition(transitionID: String, guardReference: GuardReference)
    case removeGuardFromTransition(transitionID: String)
    case addEffectToTransition(transitionID: String, effect: EffectReference)
    case removeEffectFromTransition(transitionID: String, effectIndex: Int)
}
