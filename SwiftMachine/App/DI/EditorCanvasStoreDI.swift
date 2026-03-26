//
//  EditorCanvasStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension EditorCanvasStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self {
            EditorCanvasStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                )
            )
        }
    }
}
