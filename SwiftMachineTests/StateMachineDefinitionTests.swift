//
//  StateMachineDefinitionTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 15/03/2026.
//

import Foundation
import Testing
@testable import SwiftMachine

@MainActor
struct StateMachineDefinitionTests {

    @Test("A well-formed machine validates successfully")
    func wellFormedMachineValidatesSuccessfully() {
        let machine = makeMachine(
            transitions: [
                TransitionDefinition(
                    id: "start-loading",
                    sourceStateID: "idle",
                    eventID: "begin",
                    targetStateID: "loading",
                    guard: GuardReference(name: "canBegin"),
                    effects: [EffectReference(name: "startLoading")]
                )
            ]
        )

        #expect(machine.validate().isEmpty)
        #expect(machine.isValid)
    }

    @Test("Decoding fails when initialStateID is missing")
    func decodingRequiresInitialStateID() throws {
        let json = try #require(
            """
            {
              "id": "machine",
              "name": "Loader",
              "states": [
                { "id": "idle", "name": "Idle", "properties": [] }
              ],
              "events": [
                { "id": "begin", "name": "Begin", "properties": [] }
              ],
              "transitions": []
            }
            """.data(using: .utf8)
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(StateMachineDefinition.self, from: json)
        }
    }

    @Test("Transitions decode when target-state creation metadata is absent")
    func decodingDefaultsMissingTransitionTargetStateCreation() throws {
        let json = try #require(
            """
            {
              "id": "machine",
              "name": "Loader",
              "initialStateID": "idle",
              "states": [
                { "id": "idle", "name": "Idle", "properties": [] },
                { "id": "loading", "name": "Loading", "properties": [] }
              ],
              "events": [
                { "id": "begin", "name": "Begin", "properties": [] }
              ],
              "transitions": [
                {
                  "id": "start-loading",
                  "sourceStateID": "idle",
                  "eventID": "begin",
                  "targetStateID": "loading",
                  "effects": []
                }
              ]
            }
            """.data(using: .utf8)
        )

        let decoded = try JSONDecoder().decode(StateMachineDefinition.self, from: json)

        #expect(decoded.transitions.first?.targetStateCreation == .init())
    }

    @Test("Validation fails when initialStateID points to an unknown state")
    func unknownInitialStateIsRejected() {
        let machine = makeMachine(initialStateID: "missing")

        #expect(machine.validate().contains(.unknownInitialState("missing")))
    }

    @Test("Validation fails on duplicate state IDs and names")
    func duplicateStatesAreRejected() {
        let machine = makeMachine(
            states: [
                StateDefinition(id: "idle", name: "Idle"),
                StateDefinition(id: "idle", name: "Idle")
            ]
        )

        let errors = machine.validate()

        #expect(errors.contains(.duplicateStateID("idle")))
        #expect(errors.contains(.duplicateStateName("Idle")))
    }

    @Test("Validation fails on duplicate event IDs and names")
    func duplicateEventsAreRejected() {
        let machine = makeMachine(
            events: [
                EventDefinition(id: "begin", name: "Begin"),
                EventDefinition(id: "begin", name: "Begin")
            ]
        )

        let errors = machine.validate()

        #expect(errors.contains(.duplicateEventID("begin")))
        #expect(errors.contains(.duplicateEventName("Begin")))
    }

    @Test("Validation fails on duplicate property names within a state or event")
    func duplicatePropertyNamesAreRejected() {
        let duplicatedProperties = [
            PropertyDefinition(id: "first", name: "count", type: .integer),
            PropertyDefinition(id: "second", name: "count", type: .integer)
        ]

        let machine = makeMachine(
            states: [
                StateDefinition(id: "idle", name: "Idle", properties: duplicatedProperties),
                StateDefinition(id: "loading", name: "Loading")
            ],
            events: [
                EventDefinition(id: "begin", name: "Begin", properties: duplicatedProperties)
            ]
        )

        let errors = machine.validate()

        #expect(errors.contains(.duplicateStatePropertyName(stateID: "idle", propertyName: "count")))
        #expect(errors.contains(.duplicateEventPropertyName(eventID: "begin", propertyName: "count")))
    }

    @Test("Validation fails when transitions reference unknown states or events")
    func unknownTransitionReferencesAreRejected() {
        let machine = makeMachine(
            transitions: [
                TransitionDefinition(
                    id: "broken",
                    sourceStateID: "missing-source",
                    eventID: "missing-event",
                    targetStateID: "missing-target"
                )
            ]
        )

        let errors = machine.validate()

        #expect(errors.contains(.unknownTransitionSourceState(
            transitionID: "broken",
            stateID: "missing-source"
        )))
        #expect(errors.contains(.unknownTransitionTargetState(
            transitionID: "broken",
            stateID: "missing-target"
        )))
        #expect(errors.contains(.unknownTransitionEvent(
            transitionID: "broken",
            eventID: "missing-event"
        )))
    }

    @Test("Validation fails on invalid target-state creation assignments")
    func invalidTransitionTargetStateCreationAssignmentsAreRejected() {
        let machine = makeMachine(
            states: [
                StateDefinition(
                    id: "idle",
                    name: "Idle",
                    properties: [
                        PropertyDefinition(id: "source-amount", name: "amount", type: .double)
                    ]
                ),
                StateDefinition(
                    id: "loading",
                    name: "Loading",
                    properties: [
                        PropertyDefinition(id: "target-amount", name: "amount", type: .double)
                    ]
                )
            ],
            events: [
                EventDefinition(
                    id: "begin",
                    name: "Begin",
                    properties: [
                        PropertyDefinition(id: "event-flag", name: "flag", type: .boolean)
                    ]
                )
            ],
            transitions: [
                TransitionDefinition(
                    id: "start-loading",
                    sourceStateID: "idle",
                    eventID: "begin",
                    targetStateID: "loading",
                    targetStateCreation: TransitionTargetStateCreation(
                        assignments: [
                            TransitionTargetStatePropertyAssignment(
                                targetPropertyID: "missing-target-property",
                                valueSource: .targetDefault
                            ),
                            TransitionTargetStatePropertyAssignment(
                                targetPropertyID: "target-amount",
                                valueSource: .eventProperty(propertyID: "event-flag")
                            )
                        ]
                    )
                )
            ]
        )

        let errors = machine.validate()

        #expect(errors.contains(.unknownTransitionTargetProperty(
            transitionID: "start-loading",
            stateID: "loading",
            propertyID: "missing-target-property"
        )))
        #expect(errors.contains(.incompatibleTransitionTargetPropertyAssignment(
            transitionID: "start-loading",
            targetPropertyID: "target-amount"
        )))
    }

    @Test("Guarded alternatives preserve transition order")
    func guardedAlternativesPreserveTransitionOrder() {
        let machine = makeMachine(
            states: [
                StateDefinition(id: "idle", name: "Idle"),
                StateDefinition(id: "loading", name: "Loading"),
                StateDefinition(id: "error", name: "Error")
            ],
            transitions: [
                TransitionDefinition(
                    id: "success-path",
                    sourceStateID: "idle",
                    eventID: "begin",
                    targetStateID: "loading",
                    guard: GuardReference(name: "hasInput")
                ),
                TransitionDefinition(
                    id: "failure-path",
                    sourceStateID: "idle",
                    eventID: "begin",
                    targetStateID: "error",
                    guard: GuardReference(name: "isMissingInput")
                )
            ]
        )

        #expect(machine.validate().isEmpty)
        #expect(machine.transitions.map { $0.id } == ["success-path", "failure-path"])
    }

    @Test("A transition with no guard and no effects is valid")
    func guardlessTransitionWithNoEffectsIsValid() {
        let machine = makeMachine(
            events: [EventDefinition(id: "retry", name: "Retry")],
            transitions: [
                TransitionDefinition(
                    id: "retry-self",
                    sourceStateID: "idle",
                    eventID: "retry",
                    targetStateID: "idle"
                )
            ]
        )

        #expect(machine.validate().isEmpty)
        #expect(machine.transitions.first?.guard == nil)
        #expect(machine.transitions.first?.effects.isEmpty == true)
    }

    @Test("Self-transitions and empty property lists are valid")
    func selfTransitionsAndEmptyPropertyListsAreValid() {
        let machine = StateMachineDefinition(
            id: "single-state-machine",
            name: "Single State Machine",
            initialStateID: "idle",
            states: [StateDefinition(id: "idle", name: "Idle", properties: [])],
            events: [EventDefinition(id: "ping", name: "Ping", properties: [])],
            transitions: [
                TransitionDefinition(
                    id: "loop",
                    sourceStateID: "idle",
                    eventID: "ping",
                    targetStateID: "idle"
                )
            ]
        )

        #expect(machine.validate().isEmpty)
        #expect(machine.isValid)
    }
}

private func makeMachine(
    initialStateID: String = "idle",
    states: [StateDefinition] = [
        StateDefinition(id: "idle", name: "Idle"),
        StateDefinition(id: "loading", name: "Loading")
    ],
    events: [EventDefinition] = [
        EventDefinition(id: "begin", name: "Begin")
    ],
    transitions: [TransitionDefinition] = []
) -> StateMachineDefinition {
    StateMachineDefinition(
        id: "machine",
        name: "Loader",
        initialStateID: initialStateID,
        states: states,
        events: events,
        transitions: transitions
    )
}
