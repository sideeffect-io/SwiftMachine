//
//  StateMachineEditorDocumentTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 16/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct StateMachineEditorDocumentTests {

    @Test("Bootstrapping seeds layout without mutating the semantic machine")
    func bootstrapSeedsLayout() throws {
        let machine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: []
            )
        )

        let document = StateMachineEditorDocument.bootstrap(definition: machine)

        #expect(document.definition == machine)
        #expect(document.definition.isValid)
        #expect(document.position(for: machine.initialStateID) == StateMachineEditorDocument.initialStateOrigin)
    }

    @Test("Added states receive deterministic staggered positions")
    func addedStatesReceiveDeterministicPositions() throws {
        let document = try #require(makeEditorDocument())
        let firstAdded = try #require(document.addingState())
        let secondAdded = try #require(firstAdded.document.addingState())

        let firstExpectedPosition = StateMachineEditorDocument.initialStateOrigin.translatingBy(
            dx: StateMachineEditorDocument.stateOriginOffset.x,
            dy: StateMachineEditorDocument.stateOriginOffset.y
        )
        let secondExpectedPosition = StateMachineEditorDocument.initialStateOrigin.translatingBy(
            dx: StateMachineEditorDocument.stateOriginOffset.x * 2,
            dy: StateMachineEditorDocument.stateOriginOffset.y * 2
        )

        #expect(firstAdded.document.position(for: firstAdded.stateID) == firstExpectedPosition)
        #expect(secondAdded.document.position(for: secondAdded.stateID) == secondExpectedPosition)
    }

    @Test("Added states can clone selected reusable properties")
    func addedStatesCanCloneSelectedReusableProperties() throws {
        let document = try #require(makeEditorDocument())
        let reusableProperties = [
            PropertyDefinition(name: "position", type: .integer, defaultValue: .integer(0)),
            PropertyDefinition(name: "target", type: .integer, isOptional: true, defaultValue: .integer(42))
        ]

        let addedState = try #require(
            document.addingState(
                named: "Loading",
                properties: reusableProperties
            )
        )

        let createdState = try #require(
            addedState.document.definition.states.first(where: { $0.id == addedState.stateID })
        )

        #expect(createdState.name == "Loading")
        #expect(createdState.properties.map(\.name) == ["position", "target"])
        #expect(createdState.properties.map(\.type) == [.integer, .integer])
        #expect(createdState.properties.map(\.isOptional) == [false, true])
        #expect(createdState.properties.map(\.defaultValue) == [.integer(0), .integer(42)])
        #expect(createdState.properties.map(\.id) != reusableProperties.map(\.id))
        #expect(addedState.document.definition.validate().isEmpty)
    }

    @Test("Moving layout metadata does not affect semantic validation")
    func movingLayoutDoesNotChangeDefinitionValidity() throws {
        let document = try #require(makeEditorDocument())
        let moved = document.movingState(
            id: document.definition.initialStateID,
            to: StateMachineEditorPoint(x: 840, y: 540)
        )

        #expect(moved.definition == document.definition)
        #expect(moved.definition.validate().isEmpty)
        #expect(moved.position(for: document.definition.initialStateID) == StateMachineEditorPoint(x: 840, y: 540))
    }

    @Test("Moving a transition only updates layout metadata")
    func movingTransitionDoesNotChangeDefinitionValidity() throws {
        let document = try #require(makeEditorDocument())
        let eventResult = try #require(document.addingEvent())
        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: eventResult.document.definition.initialStateID,
                targetStateID: eventResult.document.definition.initialStateID,
                eventID: eventResult.eventID
            )
        )
        let moved = transitionResult.document.movingTransition(
            id: transitionResult.transitionID,
            to: StateMachineEditorPoint(x: 980, y: 420)
        )

        #expect(moved.definition == transitionResult.document.definition)
        #expect(moved.definition.validate().isEmpty)
        #expect(moved.transitionPosition(for: transitionResult.transitionID) == StateMachineEditorPoint(x: 980, y: 420))
    }

    @Test("Renaming a state preserves layout and semantic validity")
    func renamingStatePreservesLayout() throws {
        let document = try #require(makeEditorDocument())
        let initialStateID = document.definition.initialStateID

        let updatedDocument = try #require(
            document.renamingState(
                id: initialStateID,
                to: "Waiting"
            )
        )

        let renamedState = try #require(
            updatedDocument.definition.states.first(where: { $0.id == initialStateID })
        )

        #expect(updatedDocument.position(for: initialStateID) == StateMachineEditorDocument.initialStateOrigin)
        #expect(updatedDocument.definition.validate().isEmpty)
        #expect(renamedState.name == "Waiting")
    }

    @Test("Document can create a valid self-transition and reassign its event")
    func documentCreatesAndReassignsTransitions() throws {
        let baseDocument = try #require(makeEditorDocument())
        let firstEventDocument = try #require(baseDocument.addingEvent()?.document)
        let secondEventResult = try #require(firstEventDocument.addingEvent())
        let secondEventDocument = secondEventResult.document
        let secondEventID = secondEventResult.eventID
        let initialStateID = secondEventDocument.definition.initialStateID
        let firstEventID = try #require(secondEventDocument.definition.events.first?.id)

        let transitionResult = try #require(
            secondEventDocument.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: initialStateID,
                eventID: firstEventID
            )
        )
        let reassignedDocument = try #require(
            transitionResult.document.assigningEvent(
                eventID: secondEventID,
                toTransitionID: transitionResult.transitionID
            )
        )

        let transition = try #require(reassignedDocument.definition.transitions.first)

        #expect(reassignedDocument.definition.validate().isEmpty)
        #expect(transition.sourceStateID == initialStateID)
        #expect(transition.targetStateID == initialStateID)
        #expect(transition.eventID == secondEventID)
        #expect(reassignedDocument.position(for: initialStateID) == StateMachineEditorDocument.initialStateOrigin)
    }

    @Test("Document can reassign transition routing between known states")
    func documentReassignsTransitionRouting() throws {
        let baseDocument = try #require(makeEditorDocument())
        let secondStateResult = try #require(baseDocument.addingState())
        let eventResult = try #require(secondStateResult.document.addingEvent())
        let initialStateID = secondStateResult.document.definition.initialStateID
        let secondStateID = secondStateResult.stateID

        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventResult.eventID
            )
        )
        let sourceUpdatedDocument = try #require(
            transitionResult.document.assigningSourceState(
                stateID: secondStateID,
                toTransitionID: transitionResult.transitionID
            )
        )
        let targetUpdatedDocument = try #require(
            sourceUpdatedDocument.assigningTargetState(
                stateID: initialStateID,
                toTransitionID: transitionResult.transitionID
            )
        )

        let updatedTransition = try #require(
            targetUpdatedDocument.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )

        #expect(targetUpdatedDocument.definition.validate().isEmpty)
        #expect(updatedTransition.sourceStateID == secondStateID)
        #expect(updatedTransition.targetStateID == initialStateID)
    }

    @Test("Document can add and update reusable payload types")
    func documentAddsAndUpdatesReusablePayloadTypes() throws {
        let document = try #require(makeEditorDocument())
        let structResult = try #require(document.addingStructType())
        let enumResult = try #require(structResult.document.addingEnumType())
        let structTypeID = structResult.typeID
        let enumTypeID = enumResult.typeID

        let renamedDocument = try #require(
            enumResult.document.renamingType(
                id: structTypeID,
                to: "User"
            )
        )
        let updatedDocument = try #require(
            renamedDocument.updatingType(
                PayloadTypeDefinition(
                    id: structTypeID,
                    name: "User",
                    kind: .structType(fields: [
                        PropertyDefinition(id: "field-name", name: "name", type: .string)
                    ])
                ),
                forTypeID: structTypeID
            )
        )

        let userType = try #require(
            updatedDocument.definition.types.first(where: { $0.id == structTypeID })
        )
        let enumType = try #require(
            updatedDocument.definition.types.first(where: { $0.id == enumTypeID })
        )

        #expect(updatedDocument.definition.validate().isEmpty)
        #expect(updatedDocument.statePositions == document.statePositions)
        #expect(userType.name == "User")
        #expect(userType.kind.fields.map(\.name) == ["name"])
        #expect(enumType.kind.cases.isEmpty)
    }

    @Test("Transition target-state creation reconciles when referenced properties disappear")
    func transitionTargetStateCreationReconcilesAfterPropertyChanges() throws {
        let machine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: [
                    PropertyDefinition(id: "source-amount", name: "amount", type: .double)
                ]
            )
        )
        let baseDocument = StateMachineEditorDocument.bootstrap(definition: machine)
        let secondStateResult = try #require(
            baseDocument.addingState(
                named: "Loading",
                properties: [
                    PropertyDefinition(id: "target-amount", name: "amount", type: .double)
                ]
            )
        )
        let eventResult = try #require(secondStateResult.document.addingEvent())
        let initialStateID = secondStateResult.document.definition.initialStateID
        let targetState = try #require(
            secondStateResult.document.definition.states.first(where: { $0.id == secondStateResult.stateID })
        )
        let targetAmountPropertyID = try #require(
            targetState.properties.first(where: { $0.name == "amount" })?.id
        )

        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateResult.stateID,
                eventID: eventResult.eventID
            )
        )
        let mappedDocument = try #require(
            transitionResult.document.updatingTransitionTargetStateCreation(
                TransitionTargetStateCreation(
                    assignments: [
                        TransitionTargetStatePropertyAssignment(
                            targetPropertyID: targetAmountPropertyID,
                            valueSource: .sourceStateProperty(
                                reference: PropertyValueReference(propertyID: "source-amount")
                            )
                        )
                    ]
                ),
                forTransitionID: transitionResult.transitionID
            )
        )
        let reconciledDocument = try #require(
            mappedDocument.updatingStateProperties(
                [],
                forStateID: initialStateID
            )
        )

        let reconciledTransition = try #require(
            reconciledDocument.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )

        #expect(reconciledDocument.definition.validate().isEmpty)
        #expect(
            reconciledTransition.targetStateCreation.assignments.first?.valueSource == .targetDefault
        )
    }

    @Test("Transition target-state creation preserves custom notes during reconciliation")
    func transitionTargetStateCreationPreservesCustomNotesAfterPropertyChanges() throws {
        let machine = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: [
                    PropertyDefinition(id: "source-amount", name: "amount", type: .double)
                ]
            )
        )
        let baseDocument = StateMachineEditorDocument.bootstrap(definition: machine)
        let secondStateResult = try #require(
            baseDocument.addingState(
                named: "Loading",
                properties: [
                    PropertyDefinition(id: "target-amount", name: "amount", type: .double)
                ]
            )
        )
        let eventResult = try #require(secondStateResult.document.addingEvent())
        let targetState = try #require(
            secondStateResult.document.definition.states.first(where: { $0.id == secondStateResult.stateID })
        )
        let targetAmountPropertyID = try #require(
            targetState.properties.first(where: { $0.name == "amount" })?.id
        )

        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: secondStateResult.document.definition.initialStateID,
                targetStateID: secondStateResult.stateID,
                eventID: eventResult.eventID
            )
        )
        let customMapping = TransitionTargetStateCreation(
            assignments: [
                TransitionTargetStatePropertyAssignment(
                    targetPropertyID: targetAmountPropertyID,
                    valueSource: .custom(comment: "Derived by a custom formatter before entering Loading.")
                )
            ]
        )
        let mappedDocument = try #require(
            transitionResult.document.updatingTransitionTargetStateCreation(
                customMapping,
                forTransitionID: transitionResult.transitionID
            )
        )
        let reconciledDocument = try #require(
            mappedDocument.updatingStateProperties(
                [],
                forStateID: secondStateResult.document.definition.initialStateID
            )
        )

        let reconciledTransition = try #require(
            reconciledDocument.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )

        #expect(reconciledDocument.definition.validate().isEmpty)
        #expect(reconciledTransition.targetStateCreation == customMapping)
    }

    @Test("Document can create transition events and edit guard/effect references")
    func documentEditsTransitionReferences() throws {
        let baseDocument = try #require(makeEditorDocument())
        let secondStateResult = try #require(baseDocument.addingState())
        let eventResult = try #require(secondStateResult.document.addingEvent())
        let initialStateID = secondStateResult.document.definition.initialStateID
        let secondStateID = secondStateResult.stateID

        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventResult.eventID
            )
        )
        let newEventResult = try #require(
            transitionResult.document.assigningNewEvent(
                named: "Submit",
                properties: [
                    PropertyDefinition(name: "attemptCount", type: .integer, defaultValue: .integer(1))
                ],
                toTransitionID: transitionResult.transitionID
            )
        )
        let eventUpdatedDocument = try #require(
            newEventResult.document.updatingEventProperties(
                [
                    PropertyDefinition(name: "attemptCount", type: .integer, defaultValue: .integer(2)),
                    PropertyDefinition(name: "channel", type: .string, isOptional: true)
                ],
                forEventID: newEventResult.eventID
            )
        )
        let guardedDocument = try #require(
            eventUpdatedDocument.assigningGuard(
                GuardReference(
                    name: "canSubmit",
                    description: "Checks that the form is valid"
                ),
                toTransitionID: transitionResult.transitionID
            )
        )
        let effectedDocument = try #require(
            guardedDocument.addingEffect(
                EffectReference(
                    name: "trackSubmit",
                    description: "Sends analytics"
                ),
                toTransitionID: transitionResult.transitionID
            )
        )
        let updatedEffectDocument = try #require(
            effectedDocument.updatingEffect(
                EffectReference(
                    name: "trackSubmitSuccess",
                    description: "Sends a success analytic event"
                ),
                at: 0,
                inTransitionID: transitionResult.transitionID
            )
        )
        let effectRemovedDocument = try #require(
            updatedEffectDocument.removingEffect(
                at: 0,
                fromTransitionID: transitionResult.transitionID
            )
        )
        let guardRemovedDocument = try #require(
            effectRemovedDocument.removingGuard(
                fromTransitionID: transitionResult.transitionID
            )
        )

        let updatedTransition = try #require(
            guardRemovedDocument.definition.transitions.first(where: { $0.id == transitionResult.transitionID })
        )
        let createdEvent = try #require(
            guardRemovedDocument.definition.events.first(where: { $0.id == newEventResult.eventID })
        )
        let updatedEffect = try #require(
            updatedEffectDocument.definition.transitions
                .first(where: { $0.id == transitionResult.transitionID })?
                .effects
                .first
        )

        #expect(guardRemovedDocument.definition.validate().isEmpty)
        #expect(guardRemovedDocument.definition.events.count == 2)
        #expect(createdEvent.name == "Submit")
        #expect(createdEvent.properties.map(\.name) == ["attemptCount", "channel"])
        #expect(createdEvent.properties.map(\.type) == [.integer, .string])
        #expect(createdEvent.properties.map(\.isOptional) == [false, true])
        #expect(createdEvent.properties.map(\.defaultValue) == [.integer(2), nil])
        #expect(updatedEffect.name == "trackSubmitSuccess")
        #expect(updatedEffect.description == "Sends a success analytic event")
        #expect(updatedTransition.eventID == newEventResult.eventID)
        #expect(updatedTransition.guard == nil)
        #expect(updatedTransition.effects.isEmpty)
    }

    @Test("Updating state properties preserves layout and semantic validity")
    func updatingStatePropertiesPreservesLayout() throws {
        let document = try #require(makeEditorDocument())
        let initialStateID = document.definition.initialStateID

        let updatedDocument = try #require(
            document.updatingStateProperties(
                [
                    PropertyDefinition(name: "position", type: .integer, defaultValue: .integer(0)),
                    PropertyDefinition(name: "target", type: .integer, isOptional: true, defaultValue: .integer(99))
                ],
                forStateID: initialStateID
            )
        )

        let updatedState = try #require(
            updatedDocument.definition.states.first(where: { $0.id == initialStateID })
        )

        #expect(updatedDocument.position(for: initialStateID) == StateMachineEditorDocument.initialStateOrigin)
        #expect(updatedDocument.definition.validate().isEmpty)
        #expect(updatedState.properties.map(\.name) == ["position", "target"])
        #expect(updatedState.properties.map(\.type) == [.integer, .integer])
        #expect(updatedState.properties.map(\.isOptional) == [false, true])
        #expect(updatedState.properties.map(\.defaultValue) == [.integer(0), .integer(99)])
    }

    @Test("Removing the initial state drops its layout metadata and attached transitions")
    func removingStatePrunesLayoutAndTransitions() throws {
        let baseDocument = try #require(makeEditorDocument())
        let secondStateResult = try #require(baseDocument.addingState(named: "Loading", properties: []))
        let eventResult = try #require(secondStateResult.document.addingEvent(named: "Submit", properties: []))
        let initialStateID = eventResult.document.definition.initialStateID
        let secondStateID = secondStateResult.stateID
        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventResult.eventID,
                transitionPosition: StateMachineEditorPoint(x: 720, y: 280)
            )
        )

        let updatedDocument = try #require(
            transitionResult.document.removingState(id: initialStateID)
        )

        #expect(updatedDocument.definition.initialStateID == secondStateID)
        #expect(updatedDocument.definition.states.map(\.id) == [secondStateID])
        #expect(updatedDocument.definition.transitions.isEmpty)
        #expect(updatedDocument.statePositions[initialStateID] == nil)
        #expect(updatedDocument.transitionPositions[transitionResult.transitionID] == nil)
        #expect(updatedDocument.definition.validate().isEmpty)
    }

    @Test("Removing an event drops attached transitions and transition layout metadata")
    func removingEventPrunesTransitionsAndLayout() throws {
        let baseDocument = try #require(makeEditorDocument())
        let secondStateResult = try #require(baseDocument.addingState(named: "Loading", properties: []))
        let eventResult = try #require(secondStateResult.document.addingEvent(named: "Submit", properties: []))
        let initialStateID = eventResult.document.definition.initialStateID
        let secondStateID = secondStateResult.stateID
        let transitionResult = try #require(
            eventResult.document.addingTransition(
                sourceStateID: initialStateID,
                targetStateID: secondStateID,
                eventID: eventResult.eventID,
                transitionPosition: StateMachineEditorPoint(x: 720, y: 280)
            )
        )

        let updatedDocument = try #require(
            transitionResult.document.removingEvent(id: eventResult.eventID)
        )

        #expect(updatedDocument.definition.events.isEmpty)
        #expect(updatedDocument.definition.transitions.isEmpty)
        #expect(updatedDocument.transitionPositions[transitionResult.transitionID] == nil)
        #expect(updatedDocument.definition.validate().isEmpty)
    }

    @Test("Renaming an event preserves layout and semantic validity")
    func renamingEventPreservesLayout() throws {
        let document = try #require(makeEditorDocument())
        let eventResult = try #require(
            document.addingEvent(
                named: "Submit",
                properties: [PropertyDefinition(name: "amount", type: .double)]
            )
        )

        let updatedDocument = try #require(
            eventResult.document.renamingEvent(
                id: eventResult.eventID,
                to: "Confirm"
            )
        )

        let updatedEvent = try #require(
            updatedDocument.definition.events.first(where: { $0.id == eventResult.eventID })
        )

        #expect(updatedDocument.definition.validate().isEmpty)
        #expect(updatedDocument.statePositions == eventResult.document.statePositions)
        #expect(updatedDocument.transitionPositions == eventResult.document.transitionPositions)
        #expect(updatedEvent.name == "Confirm")
    }

    @Test("Updating a type reconciles incompatible complex property defaults")
    func updatingTypeReconcilesIncompatibleComplexPropertyDefaults() throws {
        let userTypeID = "type-user"
        let machine = StateMachineDefinition(
            id: "machine",
            name: "Checkout",
            initialStateID: "idle",
            types: [
                PayloadTypeDefinition(
                    id: userTypeID,
                    name: "User",
                    kind: .structType(fields: [
                        PropertyDefinition(id: "field-name", name: "name", type: .string)
                    ])
                )
            ],
            states: [
                StateDefinition(
                    id: "idle",
                    name: "Idle",
                    properties: [
                        PropertyDefinition(
                            id: "state-user",
                            name: "user",
                            type: .model(typeID: userTypeID),
                            defaultValue: .structValue(fields: [
                                PropertyDefaultFieldValue(
                                    fieldID: "field-name",
                                    value: .string("Alice")
                                )
                            ])
                        )
                    ]
                )
            ],
            events: [],
            transitions: []
        )

        let document = StateMachineEditorDocument.bootstrap(definition: machine)
        let updatedDocument = try #require(
            document.updatingType(
                PayloadTypeDefinition(
                    id: userTypeID,
                    name: "User",
                    kind: .structType(fields: [
                        PropertyDefinition(id: "field-id", name: "id", type: .integer)
                    ])
                ),
                forTypeID: userTypeID
            )
        )

        let updatedProperty = try #require(
            updatedDocument.definition.states.first?.properties.first
        )

        #expect(updatedProperty.defaultValue == nil)
        #expect(updatedDocument.definition.validate().isEmpty)
    }

    @Test("Enabling default drafts activates literal editors")
    func enablingDefaultDraftsActivatesLiteralEditors() throws {
        var primitiveDraft = PropertyDefaultDraft(
            targetName: "value",
            targetType: .integer,
            targetSchema: .primitive(type: .integer),
            defaultValue: nil
        )

        #expect(primitiveDraft.isEnabled == false)
        #expect(primitiveDraft.literalDraft.isEnabled == false)

        primitiveDraft.setEnabled(true)

        #expect(primitiveDraft.isEnabled)
        #expect(primitiveDraft.literalDraft.isEnabled)

        var complexDraft = PropertyDefaultDraft(
            targetName: "position",
            targetType: .model(typeID: "type-position"),
            targetSchema: .structType(fields: [
                ResolvedPropertyField(
                    id: "field-value",
                    name: "value",
                    type: .integer,
                    isOptional: false,
                    schema: .primitive(type: .integer)
                )
            ]),
            defaultValue: nil
        )

        complexDraft.setEnabled(true)

        let fieldDraft = try #require(complexDraft.fieldDrafts.first)
        #expect(complexDraft.isEnabled)
        #expect(fieldDraft.valueDraft.isEnabled)
        #expect(fieldDraft.valueDraft.literalDraft.isEnabled)
    }

    @Test("Property default drafts preserve empty strings and validate typed literals")
    func propertyDefaultDraftsHandleTypedInput() {
        let stringDraft = PropertyDefaultValueDraft(defaultValue: .string(""))

        #expect(stringDraft.literalValue(for: .string) == .string(""))

        var integerDraft = PropertyDefaultValueDraft()
        integerDraft.isEnabled = true
        integerDraft.integerValue = "7"

        #expect(integerDraft.validationMessage(for: .integer) == nil)
        #expect(integerDraft.literalValue(for: .integer) == .integer(7))

        integerDraft.integerValue = "seven"

        #expect(integerDraft.validationMessage(for: .integer) != nil)
        #expect(integerDraft.literalValue(for: .integer) == nil)
    }
}

private func makeEditorDocument() -> StateMachineEditorDocument? {
    guard let machine = StateMachineDefinition.makeNew(
        name: "Checkout",
        initialStateName: "Idle",
        initialStateProperties: []
    ) else {
        return nil
    }

    return .bootstrap(definition: machine)
}
