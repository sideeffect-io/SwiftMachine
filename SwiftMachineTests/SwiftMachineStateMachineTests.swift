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
            .confirmTransitionPromptWithExistingEvent(eventID: eventID)
        )

        guard case .designing(let updatedEditor) = transition.state else {
            Issue.record("Expected the editor to stay in the designing phase.")
            return
        }

        let createdTransition = try #require(updatedEditor.document.definition.transitions.first)

        #expect(updatedEditor.document.definition.transitions.count == 1)
        #expect(createdTransition.eventID == eventID)
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
                name: "Submit"
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
        let effectRemoved = SwiftMachineStateMachine.reduce(
            effectUpdated.state,
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

        #expect(updatedEditor.selection == .transition(id: transitionResult.transitionID))
        #expect(updatedEditor.document.definition.events.count == 2)
        #expect(createdEvent.name == "Submit")
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
            .confirmTransitionPromptWithNewEvent(name: "Submit")
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
