//
//  TypeInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct TypeInspectorFeatureView: View {
    @Environment(\.typeInspectorStoreFactory) private var typeInspectorStoreFactory

    let typeID: String
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: typeInspectorStoreFactory.make(
                typeID: typeID,
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    @ViewBuilder
    private func content(for store: TypeInspectorStore) -> some View {
        Group {
            if let type = store.inspectedType,
               let definition = store.definition {
                let typeKindTint: Color = {
                    switch type.kind {
                    case .structType:
                        return .green
                    case .enumType:
                        return .purple
                    }
                }()

                VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                    EditorPanelSection(
                        title: "Selected Type",
                        description: "Reusable structs and enums let payload properties stay composable without redefining the same shape across states and events."
                    ) {
                        TypeTitleEditorView(
                            store: store,
                            type: type,
                            siblingNames: definition.types
                                .filter { $0.id != type.id }
                                .map(\.name)
                        )
                        .id("type-title-\(type.id)")

                        EditorBadge(
                            text: type.kindTitle,
                            tint: typeKindTint
                        )

                        Divider()

                        switch type.kind {
                        case .structType:
                            StructTypeFieldsEditorView(
                                store: store,
                                type: type,
                                availableModelTypes: store.availableModelTypes,
                                onSelectType: selectType
                            )
                            .id("type-fields-\(type.id)")

                        case .enumType:
                            EnumTypeCasesEditorView(
                                store: store,
                                type: type,
                                availableModelTypes: store.availableModelTypes,
                                onSelectType: selectType
                            )
                            .id("type-cases-\(type.id)")
                        }
                    }
                }
            } else {
                EmptySelectionInspectorView()
            }
        }
    }

    private func selectType(_ typeID: String) {
        sendEditorCanvasCommand(.select(.type(id: typeID)))
    }
}

private struct TypeTitleEditorView: View {
    let store: TypeInspectorStore
    let type: PayloadTypeDefinition
    let siblingNames: [String]

    @State private var nameDraft: String

    init(store: TypeInspectorStore, type: PayloadTypeDefinition, siblingNames: [String]) {
        self.store = store
        self.type = type
        self.siblingNames = siblingNames
        _nameDraft = State(initialValue: type.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Type Name", systemImage: "character.cursor.ibeam")
                .font(.subheadline.weight(.semibold))

            TextField("Type name", text: $nameDraft)
                .textFieldStyle(.roundedBorder)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset") {
                    nameDraft = type.name
                }
                .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Name", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: type.name) { _, updatedName in
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
        trimmedName != type.name
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "The type name cannot be empty."
        }

        if normalizedSiblingNames.contains(trimmedName) {
            return "Type names must stay unique within the machine."
        }

        return nil
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateTypeName(nameDraft))
    }
}

private struct StructTypeFieldsEditorView: View {
    let store: TypeInspectorStore
    let type: PayloadTypeDefinition
    let availableModelTypes: [PayloadTypeDefinition]
    let onSelectType: @MainActor @Sendable (String) -> Void

    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        store: TypeInspectorStore,
        type: PayloadTypeDefinition,
        availableModelTypes: [PayloadTypeDefinition],
        onSelectType: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.store = store
        self.type = type
        self.availableModelTypes = availableModelTypes
        self.onSelectType = onSelectType

        let fields = type.kind.fields
        _propertyDrafts = State(
            initialValue: fields.map { field in
                EditorPropertyDraft(
                    property: field,
                    availableModelTypes: availableModelTypes
                )
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Struct Fields")
                        .font(.subheadline.weight(.semibold))

                    Text("Structs reuse the same payload field editor as states and events, so composing bigger models stays familiar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Add Field", systemImage: "plus.circle") {
                    propertyDrafts.append(.init())
                }
            }

            if propertyDrafts.isEmpty {
                Label("No fields yet. Add one to make this struct reusable from state or event payloads.", systemImage: "rectangle.stack.badge.plus")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach($propertyDrafts) { $propertyDraft in
                        EditorPropertyDraftRowView(
                            propertyDraft: $propertyDraft,
                            availableModelTypes: availableModelTypes,
                            layout: .adaptiveInline,
                            onEditReferencedType: selectType
                        ) {
                            propertyDrafts.removeAll { $0.id == propertyDraft.id }
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

                Button("Apply Fields", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: type.kind) { _, _ in
            resetDrafts()
        }
    }

    private var fields: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private var originalFields: [PropertyDefinition] {
        type.kind.fields
    }

    private var isDirty: Bool {
        fields != originalFields
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var validationMessage: String? {
        propertyDrafts.validationMessage(
            emptyNameMessage: "Each field row needs a name before the struct can be updated.",
            duplicateNameMessage: "Field names must be unique within a struct."
        )
    }

    private func resetDrafts() {
        propertyDrafts = originalFields.map { field in
            EditorPropertyDraft(
                property: field,
                availableModelTypes: availableModelTypes
            )
        }
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(
            .updateType(
                PayloadTypeDefinition(
                    id: type.id,
                    name: type.name,
                    kind: .structType(fields: fields)
                )
            )
        )
    }

    private func selectType(_ typeID: String) {
        onSelectType(typeID)
    }
}

private struct EnumCaseDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var payloadType: PropertyType?

    nonisolated init(
        id: String = UUID().uuidString,
        name: String = "",
        payloadType: PropertyType? = nil
    ) {
        self.id = id
        self.name = name
        self.payloadType = payloadType
    }

    nonisolated init(payloadCase: PayloadEnumCaseDefinition) {
        self.init(
            id: payloadCase.id,
            name: payloadCase.name,
            payloadType: payloadCase.payloadType
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var caseDefinition: PayloadEnumCaseDefinition {
        PayloadEnumCaseDefinition(
            id: id,
            name: trimmedName,
            payloadType: payloadType
        )
    }
}

private struct EnumTypeCasesEditorView: View {
    let store: TypeInspectorStore
    let type: PayloadTypeDefinition
    let availableModelTypes: [PayloadTypeDefinition]
    let onSelectType: @MainActor @Sendable (String) -> Void

    @State private var caseDrafts: [EnumCaseDraft]
    @State private var defaultCaseID: String?

    init(
        store: TypeInspectorStore,
        type: PayloadTypeDefinition,
        availableModelTypes: [PayloadTypeDefinition],
        onSelectType: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.store = store
        self.type = type
        self.availableModelTypes = availableModelTypes
        self.onSelectType = onSelectType

        let cases = type.kind.cases
        _caseDrafts = State(
            initialValue: cases.map(EnumCaseDraft.init(payloadCase:))
        )
        _defaultCaseID = State(initialValue: type.kind.defaultCaseID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enum Cases")
                        .font(.subheadline.weight(.semibold))

                    Text("Each case can carry no payload or a single primitive or reusable model payload. Use a struct payload when a case needs multiple fields.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Add Case", systemImage: "plus.circle") {
                    caseDrafts.append(.init())
                }
            }

            if caseDrafts.isEmpty {
                Label("No cases yet. Add one to make this enum selectable in payload properties.", systemImage: "list.bullet.rectangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach($caseDrafts) { $caseDraft in
                        EnumCaseDraftRowView(
                            caseDraft: $caseDraft,
                            availableModelTypes: availableModelTypes,
                            isDefault: defaultCaseID == caseDraft.id,
                            onSetDefault: { isEnabled in
                                defaultCaseID = isEnabled ? caseDraft.id : nil
                            },
                            onEditReferencedType: selectType
                        ) {
                            if defaultCaseID == caseDraft.id {
                                defaultCaseID = nil
                            }
                            caseDrafts.removeAll { $0.id == caseDraft.id }
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

                Button("Apply Cases", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
        .onChange(of: type.kind) { _, _ in
            resetDrafts()
        }
    }

    private var cases: [PayloadEnumCaseDefinition] {
        caseDrafts.map(\.caseDefinition)
    }

    private var originalCases: [PayloadEnumCaseDefinition] {
        type.kind.cases
    }

    private var isDirty: Bool {
        cases != originalCases || defaultCaseID != type.kind.defaultCaseID
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var validationMessage: String? {
        let trimmedNames = caseDrafts.map(\.trimmedName)

        if trimmedNames.contains(where: \.isEmpty) {
            return "Each enum case needs a name before the enum can be updated."
        }

        if Set(trimmedNames).count != trimmedNames.count {
            return "Case names must be unique within an enum."
        }

        if let defaultCaseID,
           !caseDrafts.contains(where: { $0.id == defaultCaseID }) {
            return "The selected default case must still exist."
        }

        return nil
    }

    private func resetDrafts() {
        caseDrafts = originalCases.map(EnumCaseDraft.init(payloadCase:))
        defaultCaseID = type.kind.defaultCaseID
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(
            .updateType(
                PayloadTypeDefinition(
                    id: type.id,
                    name: type.name,
                    kind: .enumType(
                        cases: cases,
                        defaultCaseID: defaultCaseID
                    )
                )
            )
        )
    }

    private func selectType(_ typeID: String) {
        onSelectType(typeID)
    }
}

private struct EnumCaseDraftRowView: View {
    @Binding var caseDraft: EnumCaseDraft
    let availableModelTypes: [PayloadTypeDefinition]
    let isDefault: Bool
    let onSetDefault: (Bool) -> Void
    let onEditReferencedType: (String) -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Case name", text: $caseDraft.name)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .center, spacing: 12) {
                Toggle("Payload", isOn: hasPayloadBinding)
                    .toggleStyle(.switch)

                if caseDraft.payloadType != nil {
                    PropertyTypePicker(
                        selection: payloadTypeBinding,
                        availableModelTypes: availableModelTypes
                    )
                    .frame(maxWidth: 220, alignment: .leading)
                }

                Toggle(
                    "Default Case",
                    isOn: Binding(
                        get: { isDefault },
                        set: onSetDefault
                    )
                )
                .toggleStyle(.switch)

                Spacer(minLength: 0)

                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Remove case")
            }

            if let referencedTypeID = caseDraft.payloadType?.referencedTypeID {
                Button("Edit Payload Type") {
                    onEditReferencedType(referencedTypeID)
                }
                .buttonStyle(.link)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var hasPayloadBinding: Binding<Bool> {
        Binding(
            get: { caseDraft.payloadType != nil },
            set: { hasPayload in
                caseDraft.payloadType = hasPayload ? .string : nil
            }
        )
    }

    private var payloadTypeBinding: Binding<PropertyType> {
        Binding(
            get: { caseDraft.payloadType ?? .string },
            set: { caseDraft.payloadType = $0 }
        )
    }
}
