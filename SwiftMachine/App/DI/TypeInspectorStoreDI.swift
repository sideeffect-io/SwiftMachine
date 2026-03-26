//
//  TypeInspectorStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension TypeInspectorStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { typeID, sendEditorCanvasCommand in
            TypeInspectorStore(
                typeID: typeID,
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                updateTypeName: .init(
                    updateTypeName: { typeID, name in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.renamingType(id: typeID, to: name)
                        }
                    }
                ),
                updateType: .init(
                    updateType: { typeID, type in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.updatingType(type, forTypeID: typeID)
                        }
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
