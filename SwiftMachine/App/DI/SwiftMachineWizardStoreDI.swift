//
//  SwiftMachineWizardStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension SwiftMachineWizardStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self {
            SwiftMachineWizardStore(
                createInitialDefinition: .init(
                    createInitialDefinition: { machineName, initialStateName, properties, types in
                        guard let definition = StateMachineDefinition.makeNew(
                            name: machineName,
                            initialStateName: initialStateName,
                            initialStateProperties: properties,
                            types: types
                        ) else {
                            return nil
                        }

                        return service.replace(with: definition)
                    }
                )
            )
        }
    }
}
