//
//  SwiftMachineToolboxView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineToolboxView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if let editor {
                    machineSummary(editor.document.definition)
                    createSection(editor)
                    eventLibrary(editor.document.definition.events)
                } else {
                    EditorPanelSection(
                        title: "Wizard",
                        description: "The toolbox activates after the machine name and initial state have been provided."
                    ) {
                        EditorInfoRow(label: "Status", value: "Waiting for setup", symbol: "square.and.pencil")
                    }
                }

                footerNote
            }
            .padding(SwiftMachineShellMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var editor: StateMachineEditorSession? {
        guard case .designing(let editor) = store.state else {
            return nil
        }

        return editor
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Palette", systemImage: "shippingbox")
                .font(.title2.weight(.semibold))

            Text("The left panel owns machine-wide creation actions and the reusable event library for the graph.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerNote: some View {
        Label("Transitions are authored directly on the canvas by dragging from one state node to another.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func machineSummary(_ definition: StateMachineDefinition) -> some View {
        EditorPanelSection(
            title: "Definition",
            description: "The palette exposes compact machine metrics while the graph stays focused on topology."
        ) {
            EditorInfoRow(label: "Machine", value: definition.name, symbol: "point.3.connected.trianglepath.dotted")
            EditorInfoRow(label: "States", value: "\(definition.states.count)", symbol: "circle.hexagongrid")
            EditorInfoRow(label: "Events", value: "\(definition.events.count)", symbol: "bolt.horizontal.circle")
            EditorInfoRow(label: "Transitions", value: "\(definition.transitions.count)", symbol: "arrow.triangle.branch")
            EditorBadge(text: definition.isValid ? "Valid Definition" : "Invalid Definition", tint: definition.isValid ? .green : .red)
        }
    }

    private func createSection(_ editor: StateMachineEditorSession) -> some View {
        EditorPanelSection(
            title: "Create Elements",
            description: "Use the graph for topology and the palette for global machine resources."
        ) {
            ToolboxActionCard(
                symbol: "circle.hexagongrid",
                title: "Add State",
                description: "Draft a new state node, author new payload properties, or reuse ones that already exist elsewhere in the machine."
            ) {
                store.send(.addState)
            }

            if let prompt = editor.stateCreationPrompt {
                StateCreationPromptView(
                    prompt: prompt,
                    existingStateNames: editor.document.definition.states.map(\.name),
                    reusableProperties: editor.document.definition.reusableStatePropertyOptions
                )
                .id(prompt.suggestedName)
            }

            ToolboxActionCard(
                symbol: "bolt.horizontal.circle",
                title: "Add Event",
                description: "Append a reusable event definition to the machine library."
            ) {
                store.send(.addEvent)
            }
        }
    }

    private func eventLibrary(_ events: [EventDefinition]) -> some View {
        EditorPanelSection(
            title: "Event Library",
            description: "Transition creation can bind to any existing event or create a new one on drop."
        ) {
            if events.isEmpty {
                Label("No events yet. Create one here or from the transition prompt.", systemImage: "bolt.horizontal.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.body.weight(.semibold))

                                Text(event.properties.isEmpty ? "No payload" : "\(event.properties.count) payload propert\(event.properties.count == 1 ? "y" : "ies")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
            }
        }
    }
}

private struct StateCreationPromptView: View {
    @Environment(SwiftMachineStore.self) private var store

    let prompt: StateMachineStateCreationPrompt
    let existingStateNames: [String]
    let reusableProperties: [ReusableStatePropertyOption]

    @State private var nameDraft: String
    @State private var selectedPropertyIDs: Set<String>
    @State private var propertyDrafts: [StateCreationPropertyDraft]

    init(
        prompt: StateMachineStateCreationPrompt,
        existingStateNames: [String],
        reusableProperties: [ReusableStatePropertyOption]
    ) {
        self.prompt = prompt
        self.existingStateNames = existingStateNames
        self.reusableProperties = reusableProperties
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
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Properties")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Create payload fields directly in this state before it lands on the canvas.")
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
                    Label("No new properties yet. Add one here or clone reusable fields below.", systemImage: "rectangle.stack.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach($propertyDrafts) { $propertyDraft in
                            StateCreationPropertyDraftRowView(propertyDraft: $propertyDraft) {
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
                                        Text(reusableProperty.editorLabel)
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
        Set(
            existingStateNames.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
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
        propertyDrafts.map(\.propertyDefinition)
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

        let draftedPropertyNames = propertyDrafts.map(\.trimmedName)
        if draftedPropertyNames.contains(where: \.isEmpty) {
            return "Each new property needs a name before the state can be created."
        }

        let propertyNames = allProperties.map(\.name)
        if Set(propertyNames).count != propertyNames.count {
            return "Property names must stay unique within the new state."
        }

        if let defaultValueValidationMessage = propertyDrafts
            .compactMap(\.defaultValueValidationMessage)
            .first {
            return defaultValueValidationMessage
        }

        return nil
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

    private func createState() {
        guard canCreate else {
            return
        }

        store.send(
            .confirmStateCreation(
                name: nameDraft,
                properties: allProperties
            )
        )
    }
}

private struct StateCreationPropertyDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var type: PropertyType
    var isOptional: Bool
    var defaultValue: PropertyDefaultValueDraft

    init(
        id: String = UUID().uuidString,
        name: String = "",
        type: PropertyType = .string,
        isOptional: Bool = false,
        defaultValue: PropertyDefaultValueDraft = .init()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = defaultValue
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var propertyDefinition: PropertyDefinition {
        PropertyDefinition(
            name: trimmedName,
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue.literalValue(for: type)
        )
    }

    var defaultValueValidationMessage: String? {
        defaultValue.validationMessage(
            for: type,
            propertyName: trimmedName
        )
    }
}

private struct StateCreationPropertyDraftRowView: View {
    @Binding var propertyDraft: StateCreationPropertyDraft
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Property name", text: $propertyDraft.name)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 12) {
                StateCreationPropertyControlColumn(title: "Type") {
                    Picker("Type", selection: $propertyDraft.type) {
                        ForEach(PropertyType.allCases, id: \.self) { propertyType in
                            Text(propertyType.rawValue.capitalized)
                                .tag(propertyType)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                StateCreationPropertyControlColumn(title: "Optional") {
                    Toggle("", isOn: $propertyDraft.isOptional)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Spacer(minLength: 0)

                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Remove property")
            }

            PropertyDefaultValueEditor(
                type: propertyDraft.type,
                draft: $propertyDraft.defaultValue
            )
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
}

private struct StateCreationPropertyControlColumn<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            content
        }
    }
}

private struct ToolboxActionCard: View {
    let symbol: String
    let title: String
    let description: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))

                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(SwiftMachineShellMetrics.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isEnabled ? 0.05 : 0.025))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.08 : 0.04), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct ReusableStatePropertyOption: Identifiable, Hashable {
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: LiteralValue?
    let sources: [String]

    var id: String {
        [
            name,
            type.rawValue,
            isOptional ? "optional" : "required",
            defaultValue?.signatureFragment ?? "no-default"
        ].joined(separator: "|")
    }

    var editorLabel: String {
        propertyDefinition.editorLabel
    }

    var sourceSummary: String {
        "From " + sources.joined(separator: ", ")
    }

    var propertyDefinition: PropertyDefinition {
        PropertyDefinition(
            name: name,
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue
        )
    }
}

private struct ReusableStatePropertySignature: Hashable {
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: LiteralValue?
}

private extension StateMachineDefinition {
    var reusableStatePropertyOptions: [ReusableStatePropertyOption] {
        var propertySources: [ReusableStatePropertySignature: Set<String>] = [:]

        for state in states {
            for property in state.properties {
                let signature = ReusableStatePropertySignature(
                    name: property.name,
                    type: property.type,
                    isOptional: property.isOptional,
                    defaultValue: property.defaultValue
                )
                propertySources[signature, default: []].insert("state \(state.name)")
            }
        }

        for event in events {
            for property in event.properties {
                let signature = ReusableStatePropertySignature(
                    name: property.name,
                    type: property.type,
                    isOptional: property.isOptional,
                    defaultValue: property.defaultValue
                )
                propertySources[signature, default: []].insert("event \(event.name)")
            }
        }

        return propertySources
            .map { signature, sources in
                ReusableStatePropertyOption(
                    name: signature.name,
                    type: signature.type,
                    isOptional: signature.isOptional,
                    defaultValue: signature.defaultValue,
                    sources: sources.sorted()
                )
            }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    if lhs.type == rhs.type {
                        return !lhs.isOptional && rhs.isOptional
                    }

                    return lhs.type.rawValue < rhs.type.rawValue
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

private extension LiteralValue {
    var signatureFragment: String {
        switch self {
        case .string(let value):
            return "string:\(value)"
        case .integer(let value):
            return "integer:\(value)"
        case .double(let value):
            return "double:\(value)"
        case .boolean(let value):
            return "boolean:\(value)"
        }
    }
}

#Preview {
    SwiftMachineToolboxView()
        .environment(
            SwiftMachineStore()
        )
        .frame(width: SwiftMachineShellMetrics.sidebarIdealWidth, height: 700)
}
