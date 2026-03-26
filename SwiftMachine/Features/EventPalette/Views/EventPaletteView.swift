//
//  EventPaletteView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

private let eventPalettePromptAnimation = Animation.spring(response: 0.34, dampingFraction: 0.9)

struct EventPaletteView: View {
    @Environment(\.eventPaletteStoreFactory) private var eventPaletteStoreFactory

    let selectedEventID: String?
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: eventPaletteStoreFactory.make(
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    private func content(for store: EventPaletteStore) -> some View {
        EditorPanelSection(
            title: "Event Library",
            description: "Create reusable events here. Transition creation can bind to any existing event or create a new one on drop."
        ) {
            ToolboxActionCard(
                symbol: "bolt.horizontal.circle",
                title: "Add Event",
                description: "Append a reusable event definition to the machine library.",
                style: .compact
            ) {
                store.send(.addEventTapped)
            }

            if store.state.isEventCreationPromptPresented {
                EventCreationPromptView(
                    store: store,
                    onSelectType: selectType,
                    prompt: .init(suggestedName: store.suggestedEventName),
                    existingEventNames: store.events.map(\.name),
                    availableModelTypes: store.availableModelTypes
                )
                .id(store.suggestedEventName)
                .transition(.opacity)
            }

            if store.events.isEmpty {
                Label("No events yet. Create one here or from the transition prompt.", systemImage: "bolt.horizontal.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.events) { event in
                        PaletteLibraryCard(
                            symbol: "bolt.horizontal.circle.fill",
                            symbolColor: .orange,
                            title: event.name,
                            subtitle: payloadSummary(for: event.properties.count),
                            isSelected: selectedEventID == event.id
                        ) {
                            store.send(.selectEvent(id: event.id))
                        } onDelete: {
                            store.send(.deleteEvent(id: event.id))
                        }
                    }
                }
            }
        }
        .animation(eventPalettePromptAnimation, value: store.state.isEventCreationPromptPresented)
    }

    private func payloadSummary(for propertyCount: Int) -> String {
        propertyCount == 0
            ? "No payload"
            : "\(propertyCount) payload propert\(propertyCount == 1 ? "y" : "ies")"
    }

    private func selectType(_ typeID: String) {
        sendEditorCanvasCommand(.select(.type(id: typeID)))
    }
}

private struct EventCreationPromptView: View {
    let store: EventPaletteStore
    let onSelectType: @MainActor @Sendable (String) -> Void
    let prompt: StateMachineEventCreationPrompt
    let existingEventNames: [String]
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var nameDraft: String
    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        store: EventPaletteStore,
        onSelectType: @escaping @MainActor @Sendable (String) -> Void,
        prompt: StateMachineEventCreationPrompt,
        existingEventNames: [String],
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        self.store = store
        self.onSelectType = onSelectType
        self.prompt = prompt
        self.existingEventNames = existingEventNames
        self.availableModelTypes = availableModelTypes
        _nameDraft = State(initialValue: prompt.suggestedName)
        _propertyDrafts = State(initialValue: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.cardSpacing) {
            Label("New Event", systemImage: "bolt.horizontal.circle")
                .font(.subheadline.weight(.semibold))

            TextField("Event name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createEvent)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    propertyDrafts.append(.init())
                } label: {
                    Label("Add Property", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }

                if propertyDrafts.isEmpty {
                    Label("No payload properties yet. Add one if this event should carry typed data.", systemImage: "rectangle.stack.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach($propertyDrafts) { $propertyDraft in
                            EditorPropertyDraftRowView(
                                propertyDraft: $propertyDraft,
                                availableModelTypes: availableModelTypes,
                                layout: .paletteInline,
                                onEditReferencedType: selectType
                            ) {
                                removeProperty(propertyDraft.id)
                            }
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
                Button("Cancel") {
                    store.send(.cancelEventCreation)
                }

                Spacer(minLength: 12)

                Button("Create Event", systemImage: "checkmark.circle", action: createEvent)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
            }
        }
        .padding(SwiftMachineShellMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedExistingEventNames: Set<String> {
        Set(existingEventNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "The new event needs a name."
        }

        if normalizedExistingEventNames.contains(trimmedName) {
            return "Event names must stay unique within the machine."
        }

        return propertyDrafts.validationMessage(
            emptyNameMessage: "Each property row needs a name before the event can be created.",
            duplicateNameMessage: "Property names must be unique within an event."
        )
    }

    private var canCreate: Bool {
        validationMessage == nil
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func selectType(_ typeID: String) {
        onSelectType(typeID)
    }

    private func createEvent() {
        guard canCreate else {
            return
        }

        store.send(
            .confirmEventCreation(
                name: trimmedName,
                properties: propertyDefinitions
            )
        )
    }
}
