//
//  SwiftMachineToolboxView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

private let toolboxCreationPromptAnimation = Animation.spring(response: 0.34, dampingFraction: 0.9)
private let toolboxCreationPromptTransition = AnyTransition.opacity

private struct ToolboxPromptVisibility: Equatable {
    let isStatePromptPresented: Bool
    let isEventPromptPresented: Bool
}

struct SwiftMachineToolboxView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if let editor {
                    createSection(editor)
                    stateLibrary(editor)
                    eventLibrary(editor)
                    typeLibrary(editor)
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

    private var selectedStateID: String? {
        guard let editor,
              case .state(let stateID) = editor.selection else {
            return nil
        }

        return stateID
    }

    private var selectedEventID: String? {
        guard let editor,
              case .event(let eventID) = editor.selection else {
            return nil
        }

        return eventID
    }

    private var selectedTypeID: String? {
        guard let editor,
              case .type(let typeID) = editor.selection else {
            return nil
        }

        return typeID
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Palette", systemImage: "shippingbox")
                .font(.title2.weight(.semibold))

            Text("The left panel owns machine-wide creation actions plus the reusable state, event, and type libraries for the graph.")
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

    private func createSection(_ editor: StateMachineEditorSession) -> some View {
        EditorPanelSection(
            title: "Create Elements",
            description: "Use the graph for topology and this palette for shared machine resources.",
            density: .compact
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ToolboxActionCard(
                        symbol: "circle.hexagongrid",
                        title: "Add State",
                        description: "Draft a new state node and reuse payload fields already defined in the machine.",
                        style: .inlineCompact
                    ) {
                        store.send(.addState)
                    }

                    ToolboxActionCard(
                        symbol: "bolt.horizontal.circle",
                        title: "Add Event",
                        description: "Append a reusable event definition to the machine library.",
                        style: .inlineCompact
                    ) {
                        store.send(.addEvent)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    ToolboxActionCard(
                        symbol: "square.stack.3d.up",
                        title: "Add Struct",
                        description: "Create a reusable payload struct that properties can reference.",
                        style: .inlineCompact
                    ) {
                        store.send(.addStructType)
                    }

                    ToolboxActionCard(
                        symbol: "point.3.connected.trianglepath.dotted",
                        title: "Add Enum",
                        description: "Create a reusable payload enum with named cases.",
                        style: .inlineCompact
                    ) {
                        store.send(.addEnumType)
                    }
                }
            }

            if let prompt = editor.stateCreationPrompt {
                StateCreationPromptView(
                    prompt: prompt,
                    existingStateNames: editor.document.definition.states.map(\.name),
                    reusableProperties: editor.document.definition.reusableStatePropertyOptions,
                    availableModelTypes: editor.document.definition.types
                )
                .id(prompt.suggestedName)
                .transition(toolboxCreationPromptTransition)
                .zIndex(1)
            }

            if let prompt = editor.eventCreationPrompt {
                EventCreationPromptView(
                    prompt: prompt,
                    existingEventNames: editor.document.definition.events.map(\.name),
                    availableModelTypes: editor.document.definition.types
                )
                .id(prompt.suggestedName)
                .transition(toolboxCreationPromptTransition)
                .zIndex(1)
            }
        }
        .animation(
            toolboxCreationPromptAnimation,
            value: ToolboxPromptVisibility(
                isStatePromptPresented: editor.stateCreationPrompt != nil,
                isEventPromptPresented: editor.eventCreationPrompt != nil
            )
        )
    }

    private func stateLibrary(_ editor: StateMachineEditorSession) -> some View {
        let definition = editor.document.definition
        let states = definition.states

        return EditorPanelSection(
            title: "State Library",
            description: "Select a state to inspect its payload or remove it from the machine. Deleting a state also removes any attached transitions."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(states) { state in
                    PaletteLibraryCard(
                        symbol: "circle.hexagongrid.fill",
                        symbolColor: .blue,
                        title: state.name,
                        subtitle: stateLibrarySubtitle(
                            for: state,
                            initialStateID: definition.initialStateID
                        ),
                        isSelected: selectedStateID == state.id,
                        isDeleteEnabled: states.count > 1,
                        deleteHelp: states.count > 1
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
    }

    private func eventLibrary(_ editor: StateMachineEditorSession) -> some View {
        let events = editor.document.definition.events

        return EditorPanelSection(
            title: "Event Library",
            description: "Transition creation can bind to any existing event or create a new one on drop. Deleting an event also removes the related transitions."
        ) {
            if events.isEmpty {
                Label("No events yet. Create one here or from the transition prompt.", systemImage: "bolt.horizontal.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
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
    }

    private func typeLibrary(_ editor: StateMachineEditorSession) -> some View {
        let definition = editor.document.definition
        let payloadTypes = definition.types

        return EditorPanelSection(
            title: "Type Library",
            description: "Reusable structs and enums can be attached to payload properties across states and events."
        ) {
            if payloadTypes.isEmpty {
                Label("No reusable types yet. Add a struct or enum above when primitive payloads stop being enough.", systemImage: "square.stack.3d.up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(payloadTypes) { payloadType in
                        PaletteLibraryCard(
                            symbol: payloadType.paletteSymbol,
                            symbolColor: payloadType.paletteColor,
                            title: payloadType.name,
                            subtitle: payloadType.librarySummary,
                            isSelected: selectedTypeID == payloadType.id,
                            isDeleteEnabled: !definition.typeIsReferenced(payloadType.id),
                            deleteHelp: definition.typeIsReferenced(payloadType.id)
                                ? "Remove references to this type before deleting it."
                                : "Delete type"
                        ) {
                            store.send(.selectType(id: payloadType.id))
                        } onDelete: {
                            store.send(.deleteType(id: payloadType.id))
                        }
                    }
                }
            }
        }
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
}

private struct StateCreationPromptView: View {
    @Environment(SwiftMachineStore.self) private var store

    let prompt: StateMachineStateCreationPrompt
    let existingStateNames: [String]
    let reusableProperties: [ReusableStatePropertyOption]
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var nameDraft: String
    @State private var selectedPropertyIDs: Set<String>
    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        prompt: StateMachineStateCreationPrompt,
        existingStateNames: [String],
        reusableProperties: [ReusableStatePropertyOption],
        availableModelTypes: [PayloadTypeDefinition]
    ) {
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
        store.send(.selectType(id: typeID))
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

private struct EventCreationPromptView: View {
    @Environment(SwiftMachineStore.self) private var store

    let prompt: StateMachineEventCreationPrompt
    let existingEventNames: [String]
    let availableModelTypes: [PayloadTypeDefinition]

    @State private var nameDraft: String
    @State private var propertyDrafts: [EditorPropertyDraft]

    init(
        prompt: StateMachineEventCreationPrompt,
        existingEventNames: [String],
        availableModelTypes: [PayloadTypeDefinition]
    ) {
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
        Set(
            existingEventNames.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
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
        store.send(.selectType(id: typeID))
    }

    private func createEvent() {
        guard canCreate else {
            return
        }

        store.send(
            .confirmEventCreation(
                name: nameDraft,
                properties: propertyDefinitions
            )
        )
    }
}

private struct PaletteLibraryCard: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    var isSelected = false
    var isDeleteEnabled = true
    var deleteHelp = "Delete item"
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .foregroundStyle(symbolColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body.weight(.semibold))

                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(cardStroke, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDeleteEnabled ? Color.red : .secondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .disabled(!isDeleteEnabled)
            .help(deleteHelp)
        }
    }

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
    }

    private var cardStroke: Color {
        isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08)
    }
}

private struct ToolboxActionCard: View {
    enum Style {
        case regular
        case compact
        case inlineCompact

        var horizontalSpacing: CGFloat {
            switch self {
            case .regular:
                return 12
            case .compact:
                return 10
            case .inlineCompact:
                return 8
            }
        }

        var contentSpacing: CGFloat {
            switch self {
            case .regular:
                return 4
            case .compact:
                return 2
            case .inlineCompact:
                return 0
            }
        }

        var iconFont: Font {
            switch self {
            case .regular:
                return .title3
            case .compact:
                return .body.weight(.semibold)
            case .inlineCompact:
                return .footnote.weight(.semibold)
            }
        }

        var iconWidth: CGFloat {
            switch self {
            case .regular:
                return 28
            case .compact:
                return 22
            case .inlineCompact:
                return 16
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular:
                return SwiftMachineShellMetrics.cardPadding
            case .compact:
                return 12
            case .inlineCompact:
                return 10
            }
        }

        var descriptionLineLimit: Int? {
            switch self {
            case .regular:
                return nil
            case .compact:
                return 2
            case .inlineCompact:
                return nil
            }
        }

        var showsDescription: Bool {
            switch self {
            case .regular, .compact:
                return true
            case .inlineCompact:
                return false
            }
        }

        var titleFont: Font {
            switch self {
            case .regular, .compact:
                return .body.weight(.semibold)
            case .inlineCompact:
                return .footnote.weight(.semibold)
            }
        }

        var verticalAlignment: VerticalAlignment {
            switch self {
            case .regular, .compact:
                return .top
            case .inlineCompact:
                return .center
            }
        }
    }

    let symbol: String
    let title: String
    let description: String
    var style: Style = .regular
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: style.verticalAlignment, spacing: style.horizontalSpacing) {
                Image(systemName: symbol)
                    .font(style.iconFont)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                    .frame(width: style.iconWidth)

                VStack(alignment: .leading, spacing: style.contentSpacing) {
                    Text(title)
                        .font(style.titleFont)

                    if style.showsDescription {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(style.descriptionLineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(style.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .help(description)
    }
}

private struct ReusableStatePropertyOption: Identifiable, Hashable {
    let name: String
    let type: PropertyType
    let isOptional: Bool
    let defaultValue: PropertyDefaultValue?
    let sources: [String]

    var id: String {
        [
            name,
            type.rawValue,
            isOptional ? "optional" : "required",
            defaultValue?.signatureFragment ?? "no-default"
        ].joined(separator: "|")
    }

    func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        propertyDefinition.editorLabel(typeDefinitions: typeDefinitions)
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
    let defaultValue: PropertyDefaultValue?
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

    func typeIsReferenced(_ typeID: String) -> Bool {
        states.contains { state in
            state.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }
        || events.contains { event in
            event.properties.contains(where: { $0.type.referencedTypeID == typeID })
        }
        || types.contains { type in
            switch type.kind {
            case .structType(let fields):
                return fields.contains(where: { $0.type.referencedTypeID == typeID })
            case .enumType(let cases, _):
                return cases.contains(where: { $0.payloadType?.referencedTypeID == typeID })
            }
        }
    }
}

private extension PayloadTypeDefinition {
    var paletteSymbol: String {
        switch kind {
        case .structType:
            return "square.stack.3d.up.fill"
        case .enumType:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    var paletteColor: Color {
        switch kind {
        case .structType:
            return .green
        case .enumType:
            return .purple
        }
    }

    var librarySummary: String {
        switch kind {
        case .structType(let fields):
            return fields.isEmpty
                ? "Struct, no fields"
                : "Struct, \(fields.count) field\(fields.count == 1 ? "" : "s")"
        case .enumType(let cases, let defaultCaseID):
            let defaultSummary = defaultCaseID == nil ? "no default" : "default case"
            return cases.isEmpty
                ? "Enum, no cases"
                : "Enum, \(cases.count) case\(cases.count == 1 ? "" : "s"), \(defaultSummary)"
        }
    }
}

private extension PropertyDefaultValue {
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
        case .structValue(let fields):
            let fragments = fields.map { field in
                "\(field.fieldID)=\(field.value.signatureFragment)"
            }
            .joined(separator: ",")

            return "struct:{\(fragments)}"
        case .enumCase(let caseID, let payload):
            let payloadFragment = payload?.signatureFragment ?? "nil"
            return "enum:\(caseID):\(payloadFragment)"
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
