//
//  TransitionInspectorStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension TransitionInspectorStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { transitionID, sendEditorCanvasEvent in
            TransitionInspectorStore(
                transitionID: transitionID,
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                assignSourceState: .init(
                    assignSourceState: { transitionID, stateID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.assigningSourceState(
                                stateID: stateID,
                                toTransitionID: transitionID
                            )
                        }
                    }
                ),
                assignEvent: .init(
                    assignEvent: { transitionID, eventID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.assigningEvent(
                                eventID: eventID,
                                toTransitionID: transitionID
                            )
                        }
                    }
                ),
                assignNewEvent: .init(
                    assignNewEvent: { transitionID, name, properties in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.assigningNewEvent(
                                named: name,
                                properties: properties,
                                toTransitionID: transitionID
                            )?.definition
                        }
                    }
                ),
                assignTargetState: .init(
                    assignTargetState: { transitionID, stateID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.assigningTargetState(
                                stateID: stateID,
                                toTransitionID: transitionID
                            )
                        }
                    }
                ),
                updateTargetStateCreation: .init(
                    updateTargetStateCreation: { transitionID, targetStateCreation in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.updatingTargetStateCreation(
                                targetStateCreation,
                                forTransitionID: transitionID
                            )
                        }
                    }
                ),
                assignGuard: .init(
                    assignGuard: { transitionID, guardReference in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.assigningGuard(
                                guardReference,
                                toTransitionID: transitionID
                            )
                        }
                    }
                ),
                removeGuard: .init(
                    removeGuard: { transitionID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.removingGuard(
                                fromTransitionID: transitionID
                            )
                        }
                    }
                ),
                addEffect: .init(
                    addEffect: { transitionID, effect in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.addingEffect(
                                effect,
                                toTransitionID: transitionID
                            )
                        }
                    }
                ),
                updateEffect: .init(
                    updateEffect: { transitionID, index, effect in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.updatingEffect(
                                effect,
                                at: index,
                                inTransitionID: transitionID
                            )
                        }
                    }
                ),
                removeEffect: .init(
                    removeEffect: { transitionID, index in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .transition(id: transitionID)
                        ) { definition in
                            definition.removingEffect(
                                at: index,
                                fromTransitionID: transitionID
                            )
                        }
                    }
                ),
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        }
    }
}
