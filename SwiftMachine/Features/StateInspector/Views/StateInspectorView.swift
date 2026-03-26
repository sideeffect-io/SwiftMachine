//
//  StateInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct StateInspectorFeatureView: View {
    @Environment(\.stateInspectorStoreFactory) private var stateInspectorStoreFactory

    let stateID: String
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: stateInspectorStoreFactory.make(
                stateID: stateID,
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    @ViewBuilder
    private func content(for store: StateInspectorStore) -> some View {
        Group {
            if let state = store.inspectedState,
               let definition = store.definition {
                VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                    EditorPanelSection(
                        title: "Selected State",
                        description: "State cards represent nodes on the graph and define the payload available while the machine is in that state."
                    ) {
                        StateTitleEditorView(
                            store: store,
                            state: state,
                            siblingNames: definition.states
                                .filter { $0.id != state.id }
                                .map(\.name)
                        )
                        .id("title-\(state.id)")

                        if state.id == definition.initialStateID {
                            EditorBadge(text: "Initial State", tint: .green)
                        }

                        Divider()

                        StatePropertiesEditorView(
                            store: store,
                            state: state,
                            availableModelTypes: store.availableModelTypes
                        )
                        .id(state.id)
                    }
                }
            } else {
                EmptySelectionInspectorView()
            }
        }
    }
}

private struct StateTitleEditorView: View {
    let store: StateInspectorStore
    let state: StateDefinition
    let siblingNames: [String]

    @State private var nameDraft: String

    init(store: StateInspectorStore, state: StateDefinition, siblingNames: [String]) {
        self.store = store
        self.state = state
        self.siblingNames = siblingNames
        _nameDraft = State(initialValue: state.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("State Title", systemImage: "character.cursor.ibeam")
                .font(.subheadline.weight(.semibold))

            TextField("State name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset") {
                    nameDraft = state.name
                }
                .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Title", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: state.name) { _, updatedName in
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
        trimmedName != state.name
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "The state title cannot be empty."
        }

        if normalizedSiblingNames.contains(trimmedName) {
            return "State names must stay unique within the machine."
        }

        return nil
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateStateName(nameDraft))
    }
}

private struct StatePropertiesEditorView: View {
    let store: StateInspectorStore
    let state: StateDefinition
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        store: StateInspectorStore,
        state: StateDefinition,
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        self.store = store
        self.state = state
        self.availableModelTypes = availableModelTypes
        _propertyDrafts = State(
            initialValue: state.properties.map { property in
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

                    Text("Add, rename, or retune the selected state's payload fields before applying the change.")
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
                Label("No payload properties yet. Add one to attach typed data to this state.", systemImage: "rectangle.stack.badge.plus")
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
                Button("Reset") {
                    resetDrafts()
                }
                .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Properties", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: state.properties) { _, _ in
            resetDrafts()
        }
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var isDirty: Bool {
        propertyDefinitions != state.properties
    }

    private var validationMessage: String? {
        propertyDrafts.validationMessage(
            emptyNameMessage: "Each property row needs a name before the state can be updated.",
            duplicateNameMessage: "Property names must be unique within a state."
        )
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func resetDrafts() {
        propertyDrafts = state.properties.map { property in
            EditorPropertyDraft(
                property: property,
                availableModelTypes: availableModelTypes
            )
        }
    }

    private func selectType(_ typeID: String) {
        store.send(.selectType(id: typeID))
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateStateProperties(propertyDefinitions))
    }
}
