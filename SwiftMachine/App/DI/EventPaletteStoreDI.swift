//
//  EventPaletteStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension EventPaletteStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { sendEditorCanvasCommand in
            EventPaletteStore(
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                createEvent: .init(
                    createEvent: { name, properties in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.addingEvent(
                                named: name,
                                properties: properties
                            )?.definition
                        }
                    }
                ),
                deleteEvent: .init(
                    deleteEvent: { eventID in
                        applyDefinitionUpdate(using: service) { definition in
                            definition.removingEvent(id: eventID)
                        }
                    }
                ),
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        }
    }
}
