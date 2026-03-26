//
//  StatePaletteStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension StatePaletteStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { sendEditorCanvasEvent in
            StatePaletteStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createState: .init(
                    createState: { name, properties in
                        var createdStateID: String?
                        guard let snapshot = service.update({ definition in
                            let result = definition.addingState(named: name, properties: properties)
                            createdStateID = result?.stateID
                            return result?.definition
                        }),
                        let createdStateID else {
                            return nil
                        }

                        return DefinitionMutationResult(
                            snapshot: snapshot,
                            preferredSelection: .state(id: createdStateID)
                        )
                    }
                ),
                deleteState: .init(
                    deleteState: { stateID in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: nil
                        ) { definition in
                            definition.removingState(id: stateID)
                        }
                    }
                ),
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        }
    }
}
