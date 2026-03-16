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

        case (.drafting(let machineName), .setInitialState(let stateName, let properties)):
            guard let stateMachine = StateMachineDefinition.makeNew(
                name: machineName,
                initialStateName: stateName,
                initialStateProperties: properties
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
            guard let result = editor.document.addingEvent() else {
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

        case (.designing(let editor), .confirmTransitionPromptWithExistingEvent(let eventID)):
            guard let prompt = editor.transitionPrompt,
                  let result = editor.document.addingTransition(
                    sourceStateID: prompt.sourceStateID,
                    targetStateID: prompt.targetStateID,
                    eventID: eventID
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

        case (.designing(let editor), .confirmTransitionPromptWithNewEvent(let name)):
            guard let prompt = editor.transitionPrompt,
                  let result = editor.document.addingTransition(
                    sourceStateID: prompt.sourceStateID,
                    targetStateID: prompt.targetStateID,
                    newEventName: name
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

        case (.designing(let editor), .assignNewEventToTransition(let transitionID, let name)):
            guard let result = editor.document.assigningNewEvent(
                named: name,
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
}
