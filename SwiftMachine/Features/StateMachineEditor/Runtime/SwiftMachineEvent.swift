//
//  SwiftMachineEvent.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

enum SwiftMachineEvent: Sendable, Equatable {
    case createEmptyStateMachine(name: String)
    case setInitialState(name: String, properties: [PropertyDefinition], types: [PayloadTypeDefinition])
    case addState
    case confirmStateCreation(name: String, properties: [PropertyDefinition])
    case cancelStateCreation
    case addEvent
    case confirmEventCreation(name: String, properties: [PropertyDefinition])
    case cancelEventCreation
    case addStructType
    case addEnumType
    case deleteState(id: String)
    case deleteEvent(id: String)
    case deleteType(id: String)
    case updateStateName(stateID: String, name: String)
    case updateEventName(eventID: String, name: String)
    case updateTypeName(typeID: String, name: String)
    case updateStateProperties(stateID: String, properties: [PropertyDefinition])
    case updateEventProperties(eventID: String, properties: [PropertyDefinition])
    case updateType(typeID: String, type: PayloadTypeDefinition)
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
    case confirmTransitionPromptWithExistingEvent(
        eventID: String,
        properties: [PropertyDefinition],
        targetStateCreation: TransitionTargetStateCreation
    )
    case confirmTransitionPromptWithNewEvent(
        name: String,
        properties: [PropertyDefinition],
        targetStateCreation: TransitionTargetStateCreation
    )
    case cancelTransitionPrompt
    case assignSourceStateToTransition(transitionID: String, sourceStateID: String)
    case assignEventToTransition(transitionID: String, eventID: String)
    case assignNewEventToTransition(transitionID: String, name: String, properties: [PropertyDefinition])
    case assignTargetStateToTransition(transitionID: String, targetStateID: String)
    case updateTransitionTargetStateCreation(
        transitionID: String,
        targetStateCreation: TransitionTargetStateCreation
    )
    case assignGuardToTransition(transitionID: String, guardReference: GuardReference)
    case removeGuardFromTransition(transitionID: String)
    case addEffectToTransition(transitionID: String, effect: EffectReference)
    case updateEffectInTransition(transitionID: String, effectIndex: Int, effect: EffectReference)
    case removeEffectFromTransition(transitionID: String, effectIndex: Int)
}
