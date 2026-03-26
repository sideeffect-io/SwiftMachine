//
//  StateInspectorStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension StateInspectorStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { stateID, sendEditorCanvasCommand in
            StateInspectorStore(
                stateID: stateID,
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                updateStateName: .init(
                    updateStateName: { stateID, name in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.renamingState(id: stateID, to: name)
                        }
                    }
                ),
                updateStateProperties: .init(
                    updateStateProperties: { stateID, properties in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.updatingProperties(
                                properties,
                                forStateID: stateID
                            )
                        }
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
