//
//  SwiftMachineStateMachineTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 15/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct SwiftMachineStateMachineTests {

    @Test("The initial editor phase is empty")
    func initialPhaseIsEmpty() {
        #expect(SwiftMachineStore().state == .empty)
    }

    @Test("A blank machine name keeps the editor in the empty phase")
    func blankMachineNameDoesNotAdvance() {
        let transition = SwiftMachineStateMachine.reduce(
            .empty,
            .createEmptyStateMachine(name: "   ")
        )

        #expect(transition.state == .empty)
        #expect(transition.effects.isEmpty)
    }

    @Test("A valid machine name moves the editor to the drafted phase")
    func validMachineNameCreatesDraftedPhase() {
        let transition = SwiftMachineStateMachine.reduce(
            .empty,
            .createEmptyStateMachine(name: " Checkout ")
        )

        #expect(transition.state == .drafting(name: "Checkout"))
        #expect(transition.effects.isEmpty)
    }

    @Test("A blank initial state name keeps the editor in the drafted phase")
    func blankInitialStateNameDoesNotAdvance() {
        let transition = SwiftMachineStateMachine.reduce(
            .drafting(name: "Checkout"),
            .setInitialState(name: " ", properties: [])
        )

        #expect(transition.state == .drafting(name: "Checkout"))
        #expect(transition.effects.isEmpty)
    }

    @Test("A valid initial state creates the designing phase and seeds layout")
    func validInitialStateCreatesDesigningPhase() throws {
        let transition = SwiftMachineStateMachine.reduce(
            .drafting(name: "Checkout"),
            .setInitialState(
                name: "Idle",
                properties: [PropertyDefinition(name: "amount", type: .double)]
            )
        )

        guard case .designing(let editor) = transition.state else {
            Issue.record("Expected the reducer to enter the designing phase.")
            return
        }

        let stateMachine = editor.document.definition
        let initialState = try #require(stateMachine.states.first)

        #expect(transition.effects.isEmpty)
        #expect(stateMachine.name == "Checkout")
        #expect(stateMachine.initialStateID == initialState.id)
        #expect(initialState.properties.map(\.name) == ["amount"])
        #expect(initialState.properties.map(\.type) == [.double])
        #expect(stateMachine.isValid)
        #expect(editor.document.position(for: stateMachine.initialStateID) == StateMachineEditorDocument.initialStateOrigin)
        #expect(editor.selection == nil)
    }

    @Test("Selecting and clearing selection updates the editor session")
    func selectionLifecycleUpdatesSession() throws {
        let editor = try makeInitialEditor()
        let initialStateID = editor.document.definition.initialStateID

        let selected = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .selectState(id: initialStateID)
        )
        let cleared = SwiftMachineStateMachine.reduce(
            selected.state,
            .clearSelection
        )

        guard case .designing(let selectedEditor) = selected.state,
              case .designing(let clearedEditor) = cleared.state else {
            Issue.record("Expected the editor session to remain in the designing phase.")
            return
        }

        #expect(selectedEditor.selection == .state(id: initialStateID))
        #expect(clearedEditor.selection == nil)
    }

    @Test("Selecting an event updates the editor session")
    func eventSelectionUpdatesSession() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let eventID = try #require(editor.document.definition.events.first?.id)

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .selectEvent(id: eventID)
        )

        guard case .designing(let selectedEditor) = transition.state else {
            Issue.record("Expected the editor session to remain in the designing phase.")
            return
        }

        #expect(selectedEditor.selection == .event(id: eventID))
    }

    @Test("Moving a state updates layout without mutating the semantic machine")
    func movingStateKeepsSemanticDefinitionStable() throws {
        let editor = try makeInitialEditor()
        let initialStateID = editor.document.definition.initialStateID
        let nextPosition = StateMachineEditorPoint(x: 720, y: 510)

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .moveState(id: initialStateID, to: nextPosition)
        )

        guard case .designing(let movedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(movedEditor.document.definition == editor.document.definition)
        #expect(movedEditor.document.position(for: initialStateID) == nextPosition)
        #expect(movedEditor.selection == .state(id: initialStateID))
    }

    @Test("Moving a transition reroutes layout without mutating the semantic machine")
    func movingTransitionKeepsSemanticDefinitionStable() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let initialStateID = editor.document.definition.initialStateID
        let targetStateID = try #require(editor.document.definition.states.last?.id)
        let eventID = try #require(editor.document.definition.events.first?.id)
        let transitionResult = try #require(
            editor.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: targetStateID,
                eventID: eventID
            )
        )
        let nextPosition = StateMachineEditorPoint(x: 910, y: 180)

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: StateMachineEditorSession(document: transitionResult.document)),
            .moveTransition(id: transitionResult.transitionID, to: nextPosition)
        )

        guard case .designing(let movedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(movedEditor.document.definition == transitionResult.document.definition)
        #expect(movedEditor.document.transitionPosition(for: transitionResult.transitionID) == nextPosition)
        #expect(movedEditor.selection == .transition(id: transitionResult.transitionID))
    }

    @Test("Requesting a new state opens a creation prompt without mutating the definition")
    func addStateOpensCreationPrompt() throws {
        let editor = try makeInitialEditor()

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .addState
        )

        guard case .designing(let promptedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(promptedEditor.document.definition == editor.document.definition)
        #expect(promptedEditor.stateCreationPrompt?.suggestedName == "State 1")
        #expect(promptedEditor.selection == nil)
    }

    @Test("Confirming a new state creates it with the selected reusable properties")
    func confirmingStateCreationAddsSelectedProperties() throws {
        let editor = try makeInitialEditor()
        let prompt = StateMachineStateCreationPrompt(suggestedName: "State 1")
        let reusableProperties = [
            PropertyDefinition(name: "position", type: .integer),
            PropertyDefinition(name: "target", type: .integer, isOptional: true)
        ]

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: editor.document,
                    stateCreationPrompt: prompt
                )
            ),
            .confirmStateCreation(
                name: "Loading",
                properties: reusableProperties
            )
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let createdState = try #require(updatedEditor.document.definition.states.last)

        #expect(updatedEditor.document.definition.states.count == 2)
        #expect(createdState.name == "Loading")
        #expect(createdState.properties.map(\.name) == ["position", "target"])
        #expect(createdState.properties.map(\.id) != reusableProperties.map(\.id))
        #expect(updatedEditor.selection == .state(id: createdState.id))
        #expect(updatedEditor.stateCreationPrompt == nil)
    }

    @Test("Requesting a new event opens a creation prompt without mutating the definition")
    func addEventOpensCreationPrompt() throws {
        let editor = try makeInitialEditor()

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .addEvent
        )

        guard case .designing(let promptedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(promptedEditor.document.definition == editor.document.definition)
        #expect(promptedEditor.eventCreationPrompt?.suggestedName == "Event 1")
        #expect(promptedEditor.selection == nil)
    }

    @Test("Confirming a new event adds it without disturbing the current selection")
    func confirmingEventCreationAddsTypedProperties() throws {
        let editor = try makeTwoStateEditor()
        let selectedStateID = try #require(editor.document.definition.states.last?.id)
        let prompt = StateMachineEventCreationPrompt(suggestedName: "Event 1")
        let properties = [
            PropertyDefinition(name: "amount", type: .double),
            PropertyDefinition(name: "retry", type: .boolean, defaultValue: .boolean(false))
        ]

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: editor.document,
                    selection: .state(id: selectedStateID),
                    eventCreationPrompt: prompt
                )
            ),
            .confirmEventCreation(
                name: "Submit",
                properties: properties
            )
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let createdEvent = try #require(updatedEditor.document.definition.events.last)

        #expect(updatedEditor.document.definition.events.count == 1)
        #expect(createdEvent.name == "Submit")
        #expect(createdEvent.properties.map(\.name) == ["amount", "retry"])
        #expect(updatedEditor.selection == .state(id: selectedStateID))
        #expect(updatedEditor.eventCreationPrompt == nil)
    }

    @Test("Updating selected state title renames the semantic state")
    func updatingStateNameChangesSelectedState() throws {
        let editor = try makeInitialEditor()
        let initialStateID = editor.document.definition.initialStateID

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .updateStateName(stateID: initialStateID, name: "Waiting")
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedState = try #require(
            updatedEditor.document.definition.states.first(where: { $0.id == initialStateID })
        )

        #expect(updatedEditor.selection == .state(id: initialStateID))
        #expect(updatedEditor.document.position(for: initialStateID) == StateMachineEditorDocument.initialStateOrigin)
        #expect(updatedState.name == "Waiting")
    }

    @Test("Updating selected state properties mutates only the semantic payload")
    func updatingStatePropertiesChangesSelectedState() throws {
        let editor = try makeInitialEditor()
        let initialStateID = editor.document.definition.initialStateID
        let updatedProperties = [
            PropertyDefinition(name: "position", type: .integer),
            PropertyDefinition(name: "target", type: .integer, isOptional: true)
        ]

        let transition = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .updateStateProperties(stateID: initialStateID, properties: updatedProperties)
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedState = try #require(
            updatedEditor.document.definition.states.first(where: { $0.id == initialStateID })
        )

        #expect(updatedEditor.selection == .state(id: initialStateID))
        #expect(updatedEditor.document.position(for: initialStateID) == StateMachineEditorDocument.initialStateOrigin)
        #expect(updatedState.properties == updatedProperties)
    }

    @Test("Updating a selected event title keeps that event selected")
    func updatingEventNameChangesSelectedEvent() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let eventID = try #require(editor.document.definition.events.first?.id)

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: editor.document,
                    selection: .event(id: eventID)
                )
            ),
            .updateEventName(eventID: eventID, name: "Submit")
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedEvent = try #require(
            updatedEditor.document.definition.events.first(where: { $0.id == eventID })
        )

        #expect(updatedEditor.selection == .event(id: eventID))
        #expect(updatedEvent.name == "Submit")
    }

    @Test("Deleting a selected event removes related transitions and clears selection")
    func deletingEventRemovesTransitionsAndClearsSelection() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let stateMachine = editor.document.definition
        let initialStateID = stateMachine.initialStateID
        let secondStateID = try #require(stateMachine.states.last?.id)
        let eventID = try #require(stateMachine.events.first?.id)
        let transitionResult = try #require(
            editor.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventID
            )
        )

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: transitionResult.document,
                    selection: .event(id: eventID)
                )
            ),
            .deleteEvent(id: eventID)
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(updatedEditor.selection == nil)
        #expect(updatedEditor.document.definition.events.isEmpty)
        #expect(updatedEditor.document.definition.transitions.isEmpty)
    }

    @Test("Deleting the selected initial state promotes another state and clears selection")
    func deletingStatePromotesReplacementInitialState() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let initialStateID = editor.document.definition.initialStateID
        let replacementStateID = try #require(
            editor.document.definition.states.first(where: { $0.id != initialStateID })?.id
        )
        let eventID = try #require(editor.document.definition.events.first?.id)
        let transitionResult = try #require(
            editor.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: replacementStateID,
                eventID: eventID
            )
        )

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: transitionResult.document,
                    selection: .state(id: initialStateID)
                )
            ),
            .deleteState(id: initialStateID)
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(updatedEditor.selection == nil)
        #expect(updatedEditor.document.definition.initialStateID == replacementStateID)
        #expect(updatedEditor.document.definition.states.count == 1)
        #expect(updatedEditor.document.definition.transitions.isEmpty)
    }

    @Test("Dropping a connection on a target opens a transition prompt instead of creating a transition")
    func connectionCompletionOpensPrompt() throws {
        let editor = try makeTwoStateEditor()
        let sourceStateID = editor.document.definition.initialStateID
        let targetStateID = try #require(editor.document.definition.states.last?.id)
        let promptLocation = StateMachineEditorPoint(x: 640, y: 320)

        let started = SwiftMachineStateMachine.reduce(
            .designing(editor: editor),
            .startConnectionDrag(sourceStateID: sourceStateID, location: promptLocation)
        )
        let completed = SwiftMachineStateMachine.reduce(
            started.state,
            .completeConnectionDrag(targetStateID: targetStateID, promptLocation: promptLocation)
        )

        guard case .designing(let startedEditor) = started.state,
              case .designing(let completedEditor) = completed.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        #expect(startedEditor.connectionDraft?.sourceStateID == sourceStateID)
        #expect(completedEditor.document.definition.transitions.isEmpty)
        #expect(completedEditor.transitionPrompt?.sourceStateID == sourceStateID)
        #expect(completedEditor.transitionPrompt?.targetStateID == targetStateID)
        #expect(completedEditor.connectionDraft == nil)
    }

    @Test("Confirming a prompt with an existing event creates a transition")
    func confirmingPromptWithExistingEventCreatesTransition() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let stateMachine = editor.document.definition
        let sourceStateID = stateMachine.initialStateID
        let targetStateID = try #require(stateMachine.states.last?.id)
        let eventID = try #require(stateMachine.events.first?.id)
        let prompt = StateMachineTransitionPrompt(
            sourceStateID: sourceStateID,
            targetStateID: targetStateID,
            anchor: StateMachineEditorPoint(x: 640, y: 320)
        )

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: editor.document,
                    transitionPrompt: prompt
                )
            ),
            .confirmTransitionPromptWithExistingEvent(
                eventID: eventID,
                properties: [
                    PropertyDefinition(name: "source", type: .string),
                    PropertyDefinition(name: "attemptCount", type: .integer, defaultValue: .integer(1))
                ],
                targetStateCreation: .init()
            )
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let createdTransition = try #require(updatedEditor.document.definition.transitions.first)
        let updatedEvent = try #require(
            updatedEditor.document.definition.events.first(where: { $0.id == eventID })
        )

        #expect(updatedEditor.document.definition.transitions.count == 1)
        #expect(createdTransition.eventID == eventID)
        #expect(updatedEvent.properties.map(\.name) == ["source", "attemptCount"])
        #expect(updatedEvent.properties.map(\.type) == [.string, .integer])
        #expect(updatedEditor.document.transitionPosition(for: createdTransition.id) == prompt.anchor)
        #expect(updatedEditor.selection == .transition(id: createdTransition.id))
        #expect(updatedEditor.transitionPrompt == nil)
    }

    @Test("Updating selected transition routing mutates source and target states")
    func updatingTransitionRoutingChangesSelectedTransition() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let stateMachine = editor.document.definition
        let initialStateID = stateMachine.initialStateID
        let secondStateID = try #require(stateMachine.states.last?.id)
        let eventID = try #require(stateMachine.events.first?.id)
        let transitionResult = try #require(
            editor.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventID
            )
        )

        let sourceUpdated = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: transitionResult.document,
                    selection: .transition(id: transitionResult.transitionID)
                )
            ),
            .assignSourceStateToTransition(
                transitionID: transitionResult.transitionID,
                sourceStateID: secondStateID
            )
        )
        let targetUpdated = SwiftMachineStateMachine.reduce(
            sourceUpdated.state,
            .assignTargetStateToTransition(
                transitionID: transitionResult.transitionID,
                targetStateID: initialStateID
            )
        )

        guard case .designing(let updatedEditor) = targetUpdated.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedTransition = try #require(
            updatedEditor.document.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )

        #expect(updatedEditor.selection == .transition(id: transitionResult.transitionID))
        #expect(updatedTransition.sourceStateID == secondStateID)
        #expect(updatedTransition.targetStateID == initialStateID)
    }

    @Test("Updating selected transition target-state creation stores the semantic mapping")
    func updatingTransitionTargetStateCreationChangesSelectedTransition() throws {
        let machine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: [
                    PropertyDefinition(id: "source-amount", name: "amount", type: .double)
                ]
            )
        )
        let secondStateResult = try #require(
            StateMachineEditorDocument.bootstrap(definition: machine).addingState(
                named: "Loading",
                properties: [
                    PropertyDefinition(id: "target-amount", name: "amount", type: .double),
                    PropertyDefinition(id: "target-is-priority", name: "isPriority", type: .boolean)
                ]
            )
        )
        let eventResult = try #require(
            secondStateResult.document.addingEvent(
                named: "Submit",
                properties: [
                    PropertyDefinition(id: "event-is-priority", name: "isPriority", type: .boolean)
                ]
            )
        )
        let targetState = try #require(
            secondStateResult.document.definition.states.first(where: { $0.id == secondStateResult.stateID })
        )
        let targetAmountPropertyID = try #require(
            targetState.properties.first(where: { $0.name == "amount" })?.id
        )
        let targetPriorityPropertyID = try #require(
            targetState.properties.first(where: { $0.name == "isPriority" })?.id
        )
        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: secondStateResult.document.definition.initialStateID,
                targetStateID: secondStateResult.stateID,
                eventID: eventResult.eventID
            )
        )

        let mapping = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: targetAmountPropertyID,
                    valueSource: .sourceStateProperty(propertyID: "source-amount")
                ),
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: targetPriorityPropertyID,
                    valueSource: .eventProperty(propertyID: "event-is-priority")
                )
            ]
        )

        let updated = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: transitionResult.document,
                    selection: .transition(id: transitionResult.transitionID)
                )
            ),
            .updateTransitionTargetStateCreation(
                transitionID: transitionResult.transitionID,
                targetStateCreation: mapping
            )
        )

        guard case .designing(let updatedEditor) = updated.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedTransition = try #require(
            updatedEditor.document.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )

        #expect(updatedEditor.selection == .transition(id: transitionResult.transitionID))
        #expect(updatedTransition.targetStateCreation == mapping)
    }

    @Test("Updating selected transition references mutates the event, guard, and effects")
    func updatingTransitionReferencesChangesSelectedTransition() throws {
        let editor = try makeTwoStateEditorWithEvent()
        let stateMachine = editor.document.definition
        let initialStateID = stateMachine.initialStateID
        let secondStateID = try #require(stateMachine.states.last?.id)
        let eventID = try #require(stateMachine.events.first?.id)
        let transitionResult = try #require(
            editor.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventID
            )
        )

        let selectedState: SwiftMachineState = .designing(
            editor: StateMachineEditorSession(
                document: transitionResult.document,
                selection: .transition(id: transitionResult.transitionID)
            )
        )

        let eventUpdated = SwiftMachineStateMachine.reduce(
            selectedState,
            .assignNewEventToTransition(
                transitionID: transitionResult.transitionID,
                name: "Submit",
                properties: [
                    PropertyDefinition(name: "attemptCount", type: .integer, defaultValue: .integer(1))
                ]
            )
        )
        let guardUpdated = SwiftMachineStateMachine.reduce(
            eventUpdated.state,
            .assignGuardToTransition(
                transitionID: transitionResult.transitionID,
                guardReference: GuardReference(name: "canSubmit")
            )
        )
        let effectUpdated = SwiftMachineStateMachine.reduce(
            guardUpdated.state,
            .addEffectToTransition(
                transitionID: transitionResult.transitionID,
                effect: EffectReference(name: "trackSubmit")
            )
        )
        let effectEdited = SwiftMachineStateMachine.reduce(
            effectUpdated.state,
            .updateEffectInTransition(
                transitionID: transitionResult.transitionID,
                effectIndex: 0,
                effect: EffectReference(
                    name: "trackSubmitSuccess",
                    description: "Sends analytics after a successful submit"
                )
            )
        )
        let effectRemoved = SwiftMachineStateMachine.reduce(
            effectEdited.state,
            .removeEffectFromTransition(
                transitionID: transitionResult.transitionID,
                effectIndex: 0
            )
        )
        let guardRemoved = SwiftMachineStateMachine.reduce(
            effectRemoved.state,
            .removeGuardFromTransition(
                transitionID: transitionResult.transitionID
            )
        )

        guard case .designing(let updatedEditor) = guardRemoved.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let updatedTransition = try #require(
            updatedEditor.document.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )
        let createdEvent = try #require(
            updatedEditor.document.definition.events.first(where: { $0.id == updatedTransition.eventID })
        )
        guard case .designing(let effectEditedEditor) = effectEdited.state else {
            Issue.record("Expected the editor to stay in the designing phase after editing an effect.")
            return
        }

        let editedEffect = try #require(
            effectEditedEditor.document.definition.transitions
                .first(where: { $0.id == transitionResult.transitionID })?
                .effects
                .first
        )

        #expect(updatedEditor.selection == .transition(id: transitionResult.transitionID))
        #expect(updatedEditor.document.definition.events.count == 2)
        #expect(createdEvent.name == "Submit")
        #expect(editedEffect.name == "trackSubmitSuccess")
        #expect(editedEffect.description == "Sends analytics after a successful submit")
        #expect(updatedTransition.guard == nil)
        #expect(updatedTransition.effects.isEmpty)
    }

    @Test("Confirming a prompt with a new event creates both the event and the transition")
    func confirmingPromptWithNewEventCreatesEventAndTransition() throws {
        let editor = try makeTwoStateEditor()
        let sourceStateID = editor.document.definition.initialStateID
        let targetStateID = try #require(editor.document.definition.states.last?.id)
        let promptAnchor = StateMachineEditorPoint(x: 680, y: 360)
        let prompt = StateMachineTransitionPrompt(
            sourceStateID: sourceStateID,
            targetStateID: targetStateID,
            anchor: promptAnchor
        )

        let transition = SwiftMachineStateMachine.reduce(
            .designing(
                editor: StateMachineEditorSession(
                    document: editor.document,
                    transitionPrompt: prompt
                )
            ),
            .confirmTransitionPromptWithNewEvent(
                name: "Submit",
                properties: [
                    PropertyDefinition(name: "attemptCount", type: .integer, defaultValue: .integer(1))
                ],
                targetStateCreation: .init()
            )
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let definition = updatedEditor.document.definition
        let createdTransition = try #require(definition.transitions.first)
        let createdEvent = try #require(definition.events.first)

        #expect(definition.events.count == 1)
        #expect(definition.transitions.count == 1)
        #expect(createdEvent.name == "Submit")
        #expect(createdEvent.properties.map(\.name) == ["attemptCount"])
        #expect(createdEvent.properties.map(\.type) == [.integer])
        #expect(createdEvent.properties.map(\.defaultValue) == [.integer(1)])
        #expect(createdTransition.eventID == createdEvent.id)
        #expect(updatedEditor.document.transitionPosition(for: createdTransition.id) == promptAnchor)
        #expect(updatedEditor.selection == .transition(id: createdTransition.id))
    }
}

private func makeInitialEditor() throws -> StateMachineEditorSession {
    let machine = try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )

    return .bootstrap(definition: machine)
}

private func makeTwoStateEditor() throws -> StateMachineEditorSession {
    let editor = try makeInitialEditor()
    let document = try #require(editor.document.addingState()?.document)
    return StateMachineEditorSession(document: document)
}

private func makeTwoStateEditorWithEvent() throws -> StateMachineEditorSession {
    let editor = try makeTwoStateEditor()
    let document = try #require(editor.document.addingEvent()?.document)
    return StateMachineEditorSession(document: document)
}
