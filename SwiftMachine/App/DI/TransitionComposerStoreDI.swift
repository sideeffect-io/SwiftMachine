//
//  TransitionComposerStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension TransitionComposerStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { prompt, sendEditorCanvasCommand in
            TransitionComposerStore(
                prompt: prompt,
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createWithExistingEvent: .init(
                    createTransition: { prompt, eventID, properties, targetStateCreation in
                        var selectedTransitionID: String?
                        guard service.update({ definition in
                            guard let updatedDefinition = definition.updatingProperties(
                                properties,
                                forEventID: eventID
                            ),
                            let result = updatedDefinition.addingTransition(
                                sourceStateID: prompt.sourceStateID,
                                eventID: eventID,
                                targetStateID: prompt.targetStateID,
                                targetStateCreation: targetStateCreation
                            ) else {
                                return nil
                            }

                            selectedTransitionID = result.transitionID
                            return result.definition
                        }) != nil,
                        let selectedTransitionID else {
                            return nil
                        }

                        return selectedTransitionID
                    }
                ),
                createWithNewEvent: .init(
                    createTransition: { prompt, name, properties, targetStateCreation in
                        var selectedTransitionID: String?
                        guard service.update({ definition in
                            guard let eventResult = definition.addingEvent(
                                named: name,
                                properties: properties
                            ),
                            let transitionResult = eventResult.definition.addingTransition(
                                sourceStateID: prompt.sourceStateID,
                                eventID: eventResult.eventID,
                                targetStateID: prompt.targetStateID,
                                targetStateCreation: targetStateCreation
                            ) else {
                                return nil
                            }

                            selectedTransitionID = transitionResult.transitionID
                            return transitionResult.definition
                        }) != nil,
                        let selectedTransitionID else {
                            return nil
                        }

                        return selectedTransitionID
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
