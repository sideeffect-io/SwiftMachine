//
//  StoreFactoryMutationSupport.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

nonisolated func applyDefinitionUpdate(
    using service: CurrentStateMachineDefinitionService,
    _ mutate: (StateMachineDefinition) -> StateMachineDefinition?
) -> CurrentStateMachineDefinitionSnapshot? {
    service.update(mutate)
}
