//
//  TypePaletteStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension TypePaletteStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { sendEditorCanvasCommand in
            TypePaletteStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createStructType: .init(
                    createStructType: {
                        var createdTypeID: String?
                        guard service.update({ definition in
                            let result = definition.addingStructType()
                            createdTypeID = result?.typeID
                            return result?.definition
                        }) != nil,
                        let createdTypeID else {
                            return nil
                        }

                        return createdTypeID
                    }
                ),
                createEnumType: .init(
                    createEnumType: {
                        var createdTypeID: String?
                        guard service.update({ definition in
                            let result = definition.addingEnumType()
                            createdTypeID = result?.typeID
                            return result?.definition
                        }) != nil,
                        let createdTypeID else {
                            return nil
                        }

                        return createdTypeID
                    }
                ),
                deleteType: .init(
                    deleteType: { typeID in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.removingType(id: typeID)
                        }
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
