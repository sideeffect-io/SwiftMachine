//
//  EventInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct EventInspectorFeatureView: View {
    @Environment(\.eventInspectorStoreFactory) private var eventInspectorStoreFactory

    let eventID: String
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: eventInspectorStoreFactory.make(
                eventID: eventID,
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    @ViewBuilder
    private func content(for store: EventInspectorStore) -> some View {
        Group {
            if let event = store.inspectedEvent,
               let definition = store.definition {
                let transitionCount = definition.transitions.filter { $0.eventID == event.id }.count

                VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                    EditorPanelSection(
                        title: "Selected Event",
                        description: "Event cards represent reusable machine-wide inputs. Editing an event here updates every transition that binds to it."
                    ) {
                        EventTitleEditorView(
                            store: store,
                            event: event,
                            siblingNames: definition.events
                                .filter { $0.id != event.id }
                                .map(\.name)
                        )
                        .id("event-title-\(event.id)")

                        EditorBadge(
                            text: "\(transitionCount) transition\(transitionCount == 1 ? "" : "s")",
                            tint: .orange
                        )

                        Divider()

                        EventPropertiesEditorView(
                            store: store,
                            event: event,
                            availableModelTypes: store.availableModelTypes
                        )
                        .id("event-properties-\(event.id)")
                    }
                }
            } else {
                EmptySelectionInspectorView()
            }
        }
    }
}

private struct EventTitleEditorView: View {
    let store: EventInspectorStore
    let event: EventDefinition
    let siblingNames: [String]

    @State private var nameDraft: String

    init(store: EventInspectorStore, event: EventDefinition, siblingNames: [String]) {
        self.store = store
        self.event = event
        self.siblingNames = siblingNames
        _nameDraft = State(initialValue: event.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Event Title", systemImage: "character.cursor.ibeam")
                .font(.subheadline.weight(.semibold))

            TextField("Event name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset") {
                    nameDraft = event.name
                }
                .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Title", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: event.name) { _, updatedName in
            nameDraft = updatedName
        }
    }

    private var normalizedSiblingNames: Set<String> {
        Set(siblingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDirty: Bool {
        trimmedName != event.name
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "The event title cannot be empty."
        }

        if normalizedSiblingNames.contains(trimmedName) {
            return "Event names must stay unique within the machine."
        }

        return nil
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateEventName(nameDraft))
    }
}

private struct EventPropertiesEditorView: View {
    let store: EventInspectorStore
    let event: EventDefinition
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        store: EventInspectorStore,
        event: EventDefinition,
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        self.store = store
        self.event = event
        self.availableModelTypes = availableModelTypes
        _propertyDrafts = State(
            initialValue: event.properties.map { property in
                EditorPropertyDraft(
                    property: property,
                    availableModelTypes: availableModelTypes
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payload Properties")
                        .font(.subheadline.weight(.semibold))

                    Text("Add, rename, or retune the selected event's payload fields. Changes propagate to every transition that uses this event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Add Property", systemImage: "plus.circle") {
                    propertyDrafts.append(.init())
                }
            }

            if propertyDrafts.isEmpty {
                Label("No payload properties yet. Add one to attach typed data to this event.", systemImage: "rectangle.stack.badge.plus")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach($propertyDrafts) { $propertyDraft in
                        EditorPropertyDraftRowView(
                            propertyDraft: $propertyDraft,
                            availableModelTypes: availableModelTypes,
                            layout: .inspectorCompact,
                            onEditReferencedType: selectType
                        ) {
                            removeProperty(propertyDraft.id)
                        }
                    }
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset", action: resetDrafts)
                    .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Properties", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: event.properties) { _, _ in
            resetDrafts()
        }
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var isDirty: Bool {
        propertyDefinitions != event.properties
    }

    private var validationMessage: String? {
        propertyDrafts.validationMessage(
            emptyNameMessage: "Each property row needs a name before the event can be updated.",
            duplicateNameMessage: "Property names must be unique within an event."
        )
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func selectType(_ typeID: String) {
        store.send(.selectType(id: typeID))
    }

    private func resetDrafts() {
        propertyDrafts = event.properties.map { property in
            EditorPropertyDraft(
                property: property,
                availableModelTypes: availableModelTypes
            )
        }
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateEventProperties(propertyDefinitions))
    }
}
