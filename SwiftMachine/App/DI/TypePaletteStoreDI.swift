//
//  TypePaletteStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension TypePaletteStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { sendEditorCanvasEvent in
            TypePaletteStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createStructType: .init(
                    createStructType: {
                        var createdTypeID: String?
                        guard let snapshot = service.update({ definition in
                            let result = definition.addingStructType()
                            createdTypeID = result?.typeID
                            return result?.definition
                        }),
                        let createdTypeID else {
                            return nil
                        }

                        return DefinitionMutationResult(
                            snapshot: snapshot,
                            preferredSelection: .type(id: createdTypeID)
                        )
                    }
                ),
                createEnumType: .init(
                    createEnumType: {
                        var createdTypeID: String?
                        guard let snapshot = service.update({ definition in
                            let result = definition.addingEnumType()
                            createdTypeID = result?.typeID
                            return result?.definition
                        }),
                        let createdTypeID else {
                            return nil
                        }

                        return DefinitionMutationResult(
                            snapshot: snapshot,
                            preferredSelection: .type(id: createdTypeID)
                        )
                    }
                ),
                deleteType: .init(
                    deleteType: { typeID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: nil
                        ) { definition in
                            definition.removingType(id: typeID)
                        }
                    }
                ),
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        }
    }
}
