//
//  StatePaletteStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension StatePaletteStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { sendEditorCanvasCommand in
            StatePaletteStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createState: .init(
                    createState: { name, properties in
                        var createdStateID: String?
                        guard service.update({ definition in
                            let result = definition.addingState(named: name, properties: properties)
                            createdStateID = result?.stateID
                            return result?.definition
                        }) != nil,
                        let createdStateID else {
                            return nil
                        }

                        return createdStateID
                    }
                ),
                deleteState: .init(
                    deleteState: { stateID in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.removingState(id: stateID)
                        }
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
