//
//  EventInspectorStoreDI.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

extension EventInspectorStoreFactory {
    static func live(service: CurrentStateMachineDefinitionService) -> Self {
        Self { eventID, sendEditorCanvasEvent in
            EventInspectorStore(
                eventID: eventID,
                observeDefinition: .init(
                    observeDefinition: { service.observe() }
                ),
                updateEventName: .init(
                    updateEventName: { eventID, name in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .event(id: eventID)
                        ) { definition in
                            definition.renamingEvent(id: eventID, to: name)
                        }
                    }
                ),
                updateEventProperties: .init(
                    updateEventProperties: { eventID, properties in
                        applyDefinitionUpdate(
                            using: service,
                            preferredSelection: .event(id: eventID)
                        ) { definition in
                            definition.updatingProperties(
                                properties,
                                forEventID: eventID
                            )
                        }
                    }
                ),
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        }
    }
}
