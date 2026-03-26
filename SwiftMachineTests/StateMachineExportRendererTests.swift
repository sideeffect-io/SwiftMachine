//
//  StateMachineExportRendererTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

struct StateMachineExportRendererTests {

    @Test("The renderer keeps empty top-level sections explicit with none placeholders")
    func emptySectionsRenderAsNone() throws {
        let definition = try #require(
            StateMachineDefinition.makeNew(
                name: "Checkout",
                initialStateName: "Idle",
                initialStateProperties: []
            )
        )

        let renderedExport = StateMachineExportRenderer().render(
            definition: definition,
            revision: 7
        )

        #expect(renderedExport.machineName == "Checkout")
        #expect(renderedExport.revision == 7)
        #expect(renderedExport.suggestedFilename == "Checkout.state-machine.md")
        #expect(
            renderedExport.markdown
                ==
                """
                # State Machine: Checkout

                ## Machine
                - initial_state: Idle

                ## Types
                - none

                ## States
                - Idle

                ## Events
                - none

                ## Transitions
                - none
                """
                + "\n"
        )
    }

    @Test("The renderer emits compact stable Markdown for reusable types, defaults, and transitions")
    func complexDefinitionRendersStableMarkdown() {
        let definition = makeExportDefinition()

        let renderedExport = StateMachineExportRenderer().render(
            definition: definition,
            revision: 12
        )

        #expect(
            renderedExport.markdown
                ==
                """
                # State Machine: Checkout Flow

                ## Machine
                - initial_state: Idle

                ## Types
                - Money = struct { amount: double, currency: string = "EUR" }
                - Outcome = enum { pending [default], approved(Money), rejected(string) }

                ## States
                - Idle { note: string? = "draft", currencyCode: string = "EUR", budget: Money = { amount: 10.5, currency: "EUR" }, status: Outcome = .pending }
                - Loading { budget: Money, status: Outcome }
                - Review { status: Outcome }

                ## Events
                - Begin { requestedBudget: Money }
                - Retry

                ## Transitions
                - Idle -- Begin -> Loading; assign { budget <- { amount <- 42.5, currency <- source.currencyCode }, status <- .approved(event.requestedBudget) }; guard canBegin ("Budget is approved"); effects [startLoading ("Starts async work")]
                - Loading -- Retry -> Review; assign { status <- .rejected(custom("derive reason from backend response")) }
                """
                + "\n"
        )
    }

    @Test("The renderer omits internal identifiers and editor-only state")
    func rendererOmitsInternalIdentifiers() {
        let definition = makeExportDefinition()
        let renderedExport = StateMachineExportRenderer().render(
            definition: definition,
            revision: 12
        )

        let internalIdentifiers = [
            "type-money-001",
            "type-outcome-001",
            "state-idle-001",
            "state-loading-001",
            "state-review-001",
            "event-begin-001",
            "event-retry-001",
            "transition-begin-loading-001",
            "transition-retry-review-001",
            "prop-idle-note-001",
            "field-money-amount-001",
            "case-outcome-approved-001"
        ]

        for identifier in internalIdentifiers {
            #expect(!renderedExport.markdown.contains(identifier))
        }

        #expect(!renderedExport.markdown.contains("statePositions"))
        #expect(!renderedExport.markdown.contains("transitionPositions"))
        #expect(!renderedExport.markdown.contains("selection"))
    }
}

private func makeExportDefinition() -> StateMachineDefinition {
    let moneyTypeID = "type-money-001"
    let outcomeTypeID = "type-outcome-001"

    let moneyAmountFieldID = "field-money-amount-001"
    let moneyCurrencyFieldID = "field-money-currency-001"
    let outcomePendingCaseID = "case-outcome-pending-001"
    let outcomeApprovedCaseID = "case-outcome-approved-001"
    let outcomeRejectedCaseID = "case-outcome-rejected-001"

    let idleStateID = "state-idle-001"
    let loadingStateID = "state-loading-001"
    let reviewStateID = "state-review-001"

    let beginEventID = "event-begin-001"
    let retryEventID = "event-retry-001"

    let idleNotePropertyID = "prop-idle-note-001"
    let idleCurrencyPropertyID = "prop-idle-currency-001"
    let idleBudgetPropertyID = "prop-idle-budget-001"
    let idleStatusPropertyID = "prop-idle-status-001"
    let loadingBudgetPropertyID = "prop-loading-budget-001"
    let loadingStatusPropertyID = "prop-loading-status-001"
    let reviewStatusPropertyID = "prop-review-status-001"
    let beginBudgetPropertyID = "prop-begin-budget-001"

    let moneyType = PayloadTypeDefinition(
        id: moneyTypeID,
        name: "Money",
        kind: .structType(
            fields: [
                PropertyDefinition(
                    id: moneyAmountFieldID,
                    name: "amount",
                    type: .double
                ),
                PropertyDefinition(
                    id: moneyCurrencyFieldID,
                    name: "currency",
                    type: .string,
                    defaultValue: .string("EUR")
                )
            ]
        )
    )

    let outcomeType = PayloadTypeDefinition(
        id: outcomeTypeID,
        name: "Outcome",
        kind: .enumType(
            cases: [
                PayloadEnumCaseDefinition(
                    id: outcomePendingCaseID,
                    name: "pending"
                ),
                PayloadEnumCaseDefinition(
                    id: outcomeApprovedCaseID,
                    name: "approved",
                    payloadType: .model(typeID: moneyTypeID)
                ),
                PayloadEnumCaseDefinition(
                    id: outcomeRejectedCaseID,
                    name: "rejected",
                    payloadType: .string
                )
            ],
            defaultCaseID: outcomePendingCaseID
        )
    )

    return StateMachineDefinition(
        id: "machine-checkout-flow-001",
        name: "Checkout Flow",
        initialStateID: idleStateID,
        types: [
            moneyType,
            outcomeType
        ],
        states: [
            StateDefinition(
                id: idleStateID,
                name: "Idle",
                properties: [
                    PropertyDefinition(
                        id: idleNotePropertyID,
                        name: "note",
                        type: .string,
                        isOptional: true,
                        defaultValue: .string("draft")
                    ),
                    PropertyDefinition(
                        id: idleCurrencyPropertyID,
                        name: "currencyCode",
                        type: .string,
                        defaultValue: .string("EUR")
                    ),
                    PropertyDefinition(
                        id: idleBudgetPropertyID,
                        name: "budget",
                        type: .model(typeID: moneyTypeID),
                        defaultValue: .structValue(
                            fields: [
                                PropertyDefaultFieldValue(
                                    fieldID: moneyAmountFieldID,
                                    value: .double(10.5)
                                ),
                                PropertyDefaultFieldValue(
                                    fieldID: moneyCurrencyFieldID,
                                    value: .string("EUR")
                                )
                            ]
                        )
                    ),
                    PropertyDefinition(
                        id: idleStatusPropertyID,
                        name: "status",
                        type: .model(typeID: outcomeTypeID),
                        defaultValue: .enumCase(caseID: outcomePendingCaseID, payload: nil)
                    )
                ]
            ),
            StateDefinition(
                id: loadingStateID,
                name: "Loading",
                properties: [
                    PropertyDefinition(
                        id: loadingBudgetPropertyID,
                        name: "budget",
                        type: .model(typeID: moneyTypeID)
                    ),
                    PropertyDefinition(
                        id: loadingStatusPropertyID,
                        name: "status",
                        type: .model(typeID: outcomeTypeID)
                    )
                ]
            ),
            StateDefinition(
                id: reviewStateID,
                name: "Review",
                properties: [
                    PropertyDefinition(
                        id: reviewStatusPropertyID,
                        name: "status",
                        type: .model(typeID: outcomeTypeID)
                    )
                ]
            )
        ],
        events: [
            EventDefinition(
                id: beginEventID,
                name: "Begin",
                properties: [
                    PropertyDefinition(
                        id: beginBudgetPropertyID,
                        name: "requestedBudget",
                        type: .model(typeID: moneyTypeID)
                    )
                ]
            ),
            EventDefinition(
                id: retryEventID,
                name: "Retry"
            )
        ],
        transitions: [
            TransitionDefinition(
                id: "transition-begin-loading-001",
                sourceStateID: idleStateID,
                eventID: beginEventID,
                targetStateID: loadingStateID,
                targetStateCreation: TransitionTargetStateCreation(
                    assignments: [
                        TransitionTargetStatePropertyAssignment(
                            targetPropertyID: loadingBudgetPropertyID,
                            valueSource: .fieldMap(
                                fields: [
                                    TransitionTargetStateFieldAssignment(
                                        fieldID: moneyAmountFieldID,
                                        valueSource: .literal(.double(42.5))
                                    ),
                                    TransitionTargetStateFieldAssignment(
                                        fieldID: moneyCurrencyFieldID,
                                        valueSource: .sourceStateProperty(
                                            reference: PropertyValueReference(
                                                propertyID: idleCurrencyPropertyID
                                            )
                                        )
                                    )
                                ]
                            )
                        ),
                        TransitionTargetStatePropertyAssignment(
                            targetPropertyID: loadingStatusPropertyID,
                            valueSource: .enumCase(
                                caseID: outcomeApprovedCaseID,
                                payload: .eventProperty(
                                    reference: PropertyValueReference(
                                        propertyID: beginBudgetPropertyID
                                    )
                                )
                            )
                        )
                    ]
                ),
                guard: GuardReference(
                    name: "canBegin",
                    description: "Budget is approved"
                ),
                effects: [
                    EffectReference(
                        name: "startLoading",
                        description: "Starts async work"
                    )
                ]
            ),
            TransitionDefinition(
                id: "transition-retry-review-001",
                sourceStateID: loadingStateID,
                eventID: retryEventID,
                targetStateID: reviewStateID,
                targetStateCreation: TransitionTargetStateCreation(
                    assignments: [
                        TransitionTargetStatePropertyAssignment(
                            targetPropertyID: reviewStatusPropertyID,
                            valueSource: .enumCase(
                                caseID: outcomeRejectedCaseID,
                                payload: .custom(comment: "derive reason from backend response")
                            )
                        )
                    ]
                )
            )
        ]
    )
}
