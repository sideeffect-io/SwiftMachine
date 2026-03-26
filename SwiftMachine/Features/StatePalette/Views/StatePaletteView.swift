//
//  StatePaletteView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

private let statePalettePromptAnimation = Animation.spring(response: 0.34, dampingFraction: 0.9)

struct StatePaletteView: View {
    @Environment(\.statePaletteStoreFactory) private var statePaletteStoreFactory

    let selectedStateID: String?
    let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    var body: some View {
        WithViewStore(
            store: statePaletteStoreFactory.make(
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        ) { store in
            content(for: store)
        }
    }

    private func content(for store: StatePaletteStore) -> some View {
        EditorPanelSection(
            title: "State Library",
            description: "Create states, inspect them from the graph, and remove unused ones. Deleting a state also removes attached transitions."
        ) {
            ToolboxActionCard(
                symbol: "circle.hexagongrid",
                title: "Add State",
                description: "Draft a new state node and optionally clone reusable payload fields already defined in the machine.",
                style: .compact
            ) {
                store.send(.addStateTapped)
            }

            if store.state.isStateCreationPromptPresented {
                StateCreationPromptView(
                    store: store,
                    onSelectType: selectType,
                    prompt: .init(suggestedName: store.suggestedStateName),
                    existingStateNames: store.states.map(\.name),
                    reusableProperties: store.reusableProperties,
                    availableModelTypes: store.availableModelTypes
                )
                .id(store.suggestedStateName)
                .transition(.opacity)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.states) { state in
                    PaletteLibraryCard(
                        symbol: "circle.hexagongrid.fill",
                        symbolColor: .blue,
                        title: state.name,
                        subtitle: stateLibrarySubtitle(
                            for: state,
                            initialStateID: store.definition?.initialStateID ?? ""
                        ),
                        isSelected: selectedStateID == state.id,
                        isDeleteEnabled: store.states.count > 1,
                        deleteHelp: store.states.count > 1
                            ? "Delete state"
                            : "At least one state must remain in the machine."
                    ) {
                        store.send(.selectState(id: state.id))
                    } onDelete: {
                        store.send(.deleteState(id: state.id))
                    }
                }
            }
        }
        .animation(statePalettePromptAnimation, value: store.state.isStateCreationPromptPresented)
    }

    private func stateLibrarySubtitle(
        for state: StateDefinition,
        initialStateID: String
    ) -> String {
        let payloadText = payloadSummary(for: state.properties.count)

        guard state.id == initialStateID else {
            return payloadText
        }

        return "Initial state, \(payloadText.lowercased())"
    }

    private func payloadSummary(for propertyCount: Int) -> String {
        propertyCount == 0
            ? "No payload"
            : "\(propertyCount) payload propert\(propertyCount == 1 ? "y" : "ies")"
    }

    private func selectType(_ typeID: String) {
        sendEditorCanvasEvent(.selectType(id: typeID))
    }
}

private struct StateCreationPromptView: View {
    let store: StatePaletteStore
    let onSelectType: @MainActor @Sendable (String) -> Void
    let prompt: StateMachineStateCreationPrompt
    let existingStateNames: [String]
    let reusableProperties: [ReusableStatePropertyOption]
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var nameDraft: String
    @State private var selectedPropertyIDs: Set<String>
    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        store: StatePaletteStore,
        onSelectType: @escaping @MainActor @Sendable (String) -> Void,
        prompt: StateMachineStateCreationPrompt,
        existingStateNames: [String],
        reusableProperties: [ReusableStatePropertyOption],
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        self.store = store
        self.onSelectType = onSelectType
        self.prompt = prompt
        self.existingStateNames = existingStateNames
        self.reusableProperties = reusableProperties
        self.availableModelTypes = availableModelTypes
        _nameDraft = State(initialValue: prompt.suggestedName)
        _selectedPropertyIDs = State(initialValue: [])
        _propertyDrafts = State(initialValue: [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.cardSpacing) {
            Label("New State", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))

            TextField("State name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createState)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    propertyDrafts.append(.init())
                } label: {
                    Label("Add Property", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }

                if propertyDrafts.isEmpty {
                    Label("No new properties yet. Add one here or clone reusable fields below.", systemImage: "rectangle.stack.badge.plus")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Reusable Properties")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if reusableProperties.isEmpty {
                    Label("No reusable properties yet. Add new payload fields above or tune them later from the inspector.", systemImage: "rectangle.stack.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(selectedProperties.isEmpty ? "Pick any existing payload fields you want to clone into this state." : "\(selectedProperties.count) reusable propert\(selectedProperties.count == 1 ? "y" : "ies") selected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(reusableProperties) { reusableProperty in
                            Button {
                                toggle(reusableProperty)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: isSelected(reusableProperty) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected(reusableProperty) ? Color.accentColor : .secondary)
                                        .font(.body)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reusableProperty.editorLabel(typeDefinitions: availableModelTypes))
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)

                                        Text(reusableProperty.sourceSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.primary.opacity(isSelected(reusableProperty) ? 0.08 : 0.04))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isSelected(reusableProperty)
                                            ? Color.accentColor.opacity(0.45)
                                            : Color.primary.opacity(0.06),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
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
                    store.send(.cancelStateCreation)
                }

                Spacer(minLength: 12)

                Button("Create State", systemImage: "checkmark.circle", action: createState)
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

    private var normalizedExistingStateNames: Set<String> {
        Set(existingStateNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedProperties: [PropertyDefinition] {
        reusableProperties
            .filter { selectedPropertyIDs.contains($0.id) }
            .map(\.propertyDefinition)
    }

    private var draftedProperties: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private var allProperties: [PropertyDefinition] {
        selectedProperties + draftedProperties
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "The new state needs a name."
        }

        if normalizedExistingStateNames.contains(trimmedName) {
            return "State names must stay unique within the machine."
        }

        let propertyNames = allProperties.map(\.name)
        if Set(propertyNames).count != propertyNames.count {
            return "Property names must stay unique within the new state."
        }

        return propertyDrafts.validationMessage(
            emptyNameMessage: "Each new property needs a name before the state can be created.",
            duplicateNameMessage: "Property names must stay unique within the new state."
        )
    }

    private var canCreate: Bool {
        validationMessage == nil
    }

    private func isSelected(_ reusableProperty: ReusableStatePropertyOption) -> Bool {
        selectedPropertyIDs.contains(reusableProperty.id)
    }

    private func toggle(_ reusableProperty: ReusableStatePropertyOption) {
        if isSelected(reusableProperty) {
            selectedPropertyIDs.remove(reusableProperty.id)
            return
        }

        let conflictingIDs = reusableProperties
            .filter { $0.name == reusableProperty.name }
            .map(\.id)

        selectedPropertyIDs.subtract(conflictingIDs)
        selectedPropertyIDs.insert(reusableProperty.id)
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func selectType(_ typeID: String) {
        onSelectType(typeID)
    }

    private func createState() {
        guard canCreate else {
            return
        }

        store.send(
            .confirmStateCreation(
                name: trimmedName,
                properties: allProperties
            )
        )
    }
}
