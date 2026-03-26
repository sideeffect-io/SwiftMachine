//
//  StoreFactoryMutationSupport.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

nonisolated func applyDefinitionUpdate(
    using service: CurrentStateMachineDefinitionService,
    preferredSelection: StateMachineEditorSelection?,
    _ mutate: (StateMachineDefinition) -> StateMachineDefinition?
) -> DefinitionMutationResult? {
    guard let snapshot = service.update(mutate) else {
        return nil
    }

    return DefinitionMutationResult(
        snapshot: snapshot,
        preferredSelection: preferredSelection
    )
}
