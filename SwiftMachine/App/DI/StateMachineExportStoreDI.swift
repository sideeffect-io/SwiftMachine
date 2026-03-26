//
//  StateMachineExportStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension StateMachineExportStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self {
            StateMachineExportStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                saveRenderedExport: .live()
            )
        }
    }
}
