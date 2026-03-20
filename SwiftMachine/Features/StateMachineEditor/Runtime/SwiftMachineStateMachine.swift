//
//  SwiftMachineStateMachine.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

struct Transition<State: Sendable, Effect: Sendable>: Sendable {
    let state: State
    let effects: [Effect]
}

enum SwiftMachineStateMachine {
    static func reduce(
        _ phase: SwiftMachineState,
        _ event: SwiftMachineEvent
    ) -> Transition<SwiftMachineState, SwiftMachineEffect> {
        switch (phase, event) {
        case (.empty, .createEmptyStateMachine(let name)):
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedName.isEmpty else {
                return .init(state: .empty, effects: [])
            }

            return .init(state: .drafting(name: trimmedName), effects: [])

        case (.drafting(let machineName), .setInitialState(let stateName, let properties, let types)):
            guard let stateMachine = StateMachineDefinition.makeNew(
                name: machineName,
                initialStateName: stateName,
                initialStateProperties: properties,
                types: types
            ) else {
                return .init(state: .drafting(name: machineName), effects: [])
            }

            return .init(
                state: .designing(editor: .bootstrap(definition: stateMachine)),
                effects: []
            )

        case (.designing(let editor), .addState):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection,
                        stateCreationPrompt: StateMachineStateCreationPrompt(
                            suggestedName: editor.document.suggestedStateName()
                        )
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .confirmStateCreation(let name, let properties)):
            guard editor.stateCreationPrompt != nil,
                  let result = editor.document.addingState(
                    named: name,
                    properties: properties
                  ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .state(id: result.stateID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .cancelStateCreation):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .addEvent):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection,
                        eventCreationPrompt: StateMachineEventCreationPrompt(
                            suggestedName: editor.document.suggestedEventName()
                        )
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .confirmEventCreation(let name, let properties)):
            guard editor.eventCreationPrompt != nil,
                  let result = editor.document.addingEvent(
                    named: name,
                    properties: properties
                  ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: editor.selection
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .cancelEventCreation):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .addStructType):
            guard let result = editor.document.addingStructType() else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .type(id: result.typeID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .addEnumType):
            guard let result = editor.document.addingEnumType() else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .type(id: result.typeID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .deleteState(let stateID)):
            guard let updatedDocument = editor.document.removingState(id: stateID) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: reconciledSelection(editor.selection, in: updatedDocument)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .deleteEvent(let eventID)):
            guard let updatedDocument = editor.document.removingEvent(id: eventID) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: reconciledSelection(editor.selection, in: updatedDocument)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .deleteType(let typeID)):
            guard let updatedDocument = editor.document.removingType(id: typeID) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: reconciledSelection(editor.selection, in: updatedDocument)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateStateName(let stateID, let name)):
            guard let updatedDocument = editor.document.renamingState(
                id: stateID,
                to: name
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .state(id: stateID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateEventName(let eventID, let name)):
            guard let updatedDocument = editor.document.renamingEvent(
                id: eventID,
                to: name
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .event(id: eventID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateTypeName(let typeID, let name)):
            guard let updatedDocument = editor.document.renamingType(
                id: typeID,
                to: name
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .type(id: typeID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateStateProperties(let stateID, let properties)):
            guard let updatedDocument = editor.document.updatingStateProperties(
                properties,
                forStateID: stateID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .state(id: stateID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateEventProperties(let eventID, let properties)):
            guard let updatedDocument = editor.document.updatingEventProperties(
                properties,
                forEventID: eventID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: reconciledSelection(editor.selection, in: updatedDocument),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateType(let typeID, let type)):
            guard let updatedDocument = editor.document.updatingType(
                type,
                forTypeID: typeID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .type(id: typeID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .selectState(let stateID)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: .state(id: stateID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .selectEvent(let eventID)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: .event(id: eventID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .selectType(let typeID)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: .type(id: typeID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .selectTransition(let transitionID)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .clearSelection):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .moveState(let stateID, let position)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document.movingState(id: stateID, to: position),
                        selection: .state(id: stateID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .moveTransition(let transitionID, let position)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document.movingTransition(id: transitionID, to: position),
                        selection: .transition(id: transitionID),
                        connectionDraft: editor.connectionDraft,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .startConnectionDrag(let sourceStateID, let location)):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: .state(id: sourceStateID),
                        connectionDraft: StateMachineConnectionDraft(
                            sourceStateID: sourceStateID,
                            currentLocation: location
                        )
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateConnectionDrag(let location)):
            guard let connectionDraft = editor.connectionDraft else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection,
                        connectionDraft: StateMachineConnectionDraft(
                            sourceStateID: connectionDraft.sourceStateID,
                            currentLocation: location
                        )
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .completeConnectionDrag(let targetStateID, let promptLocation)):
            guard let connectionDraft = editor.connectionDraft else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            guard let targetStateID else {
                return .init(
                    state: .designing(
                        editor: StateMachineEditorSession(
                            document: editor.document,
                            selection: .state(id: connectionDraft.sourceStateID)
                        )
                    ),
                    effects: []
                )
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        transitionPrompt: StateMachineTransitionPrompt(
                            sourceStateID: connectionDraft.sourceStateID,
                            targetStateID: targetStateID,
                            anchor: promptLocation
                        )
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .cancelConnectionDrag):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection,
                        transitionPrompt: editor.transitionPrompt
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .confirmTransitionPromptWithExistingEvent(
            let eventID,
            let properties,
            let targetStateCreation
        )):
            guard let prompt = editor.transitionPrompt,
                  let updatedEventDocument = editor.document.updatingEventProperties(
                    properties,
                    forEventID: eventID
                  ),
                  let result = updatedEventDocument.addingTransition(
                    sourceStateID: prompt.sourceStateID,
                    targetStateID: prompt.targetStateID,
                    eventID: eventID,
                    targetStateCreation: targetStateCreation,
                    transitionPosition: prompt.anchor
                  ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .transition(id: result.transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .confirmTransitionPromptWithNewEvent(
            let name,
            let properties,
            let targetStateCreation
        )):
            guard let prompt = editor.transitionPrompt,
                  let result = editor.document.addingTransition(
                    sourceStateID: prompt.sourceStateID,
                    targetStateID: prompt.targetStateID,
                    newEventName: name,
                    eventProperties: properties,
                    targetStateCreation: targetStateCreation,
                    transitionPosition: prompt.anchor
                  ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .transition(id: result.transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .cancelTransitionPrompt):
            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: editor.document,
                        selection: editor.selection
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .assignSourceStateToTransition(let transitionID, let sourceStateID)):
            guard let updatedDocument = editor.document.assigningSourceState(
                stateID: sourceStateID,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .assignEventToTransition(let transitionID, let eventID)):
            guard let updatedDocument = editor.document.assigningEvent(
                eventID: eventID,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .assignNewEventToTransition(let transitionID, let name, let properties)):
            guard let result = editor.document.assigningNewEvent(
                named: name,
                properties: properties,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: result.document,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .assignTargetStateToTransition(let transitionID, let targetStateID)):
            guard let updatedDocument = editor.document.assigningTargetState(
                stateID: targetStateID,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateTransitionTargetStateCreation(let transitionID, let targetStateCreation)):
            guard let updatedDocument = editor.document.updatingTransitionTargetStateCreation(
                targetStateCreation,
                forTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .assignGuardToTransition(let transitionID, let guardReference)):
            guard let updatedDocument = editor.document.assigningGuard(
                guardReference,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .removeGuardFromTransition(let transitionID)):
            guard let updatedDocument = editor.document.removingGuard(
                fromTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .addEffectToTransition(let transitionID, let effect)):
            guard let updatedDocument = editor.document.addingEffect(
                effect,
                toTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .updateEffectInTransition(let transitionID, let effectIndex, let effect)):
            guard let updatedDocument = editor.document.updatingEffect(
                effect,
                at: effectIndex,
                inTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        case (.designing(let editor), .removeEffectFromTransition(let transitionID, let effectIndex)):
            guard let updatedDocument = editor.document.removingEffect(
                at: effectIndex,
                fromTransitionID: transitionID
            ) else {
                return .init(state: .designing(editor: editor), effects: [])
            }

            return .init(
                state: .designing(
                    editor: StateMachineEditorSession(
                        document: updatedDocument,
                        selection: .transition(id: transitionID)
                    )
                ),
                effects: []
            )

        default:
            return .init(state: phase, effects: [])
        }
    }

    private static func reconciledSelection(
        _ selection: StateMachineEditorSelection?,
        in document: StateMachineEditorDocument
    ) -> StateMachineEditorSelection? {
        guard let selection else {
            return nil
        }

        return selection.exists(in: document.definition) ? selection : nil
    }
}
