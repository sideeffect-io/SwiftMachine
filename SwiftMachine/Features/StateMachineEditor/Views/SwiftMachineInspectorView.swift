//
//  SwiftMachineInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct SwiftMachineInspectorView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if let editor {
                    inspectorContent(editor: editor)
                } else {
                    EditorPanelSection(
                        title: "Inspector",
                        description: "Selection details appear here once the machine enters the designing phase."
                    ) {
                        Label("No active editor session", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(SwiftMachineShellMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(sidebarBackground)
        .overlay(alignment: .leading) {
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
            Label("Inspector", systemImage: "sidebar.right")
                .font(.title2.weight(.semibold))

            Text("The right panel follows the selected state or transition and summarizes the current graph semantics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func inspectorContent(editor: StateMachineEditorSession) -> some View {
        switch editor.selection {
        case .state(let stateID):
            if let state = editor.document.definition.states.first(where: { $0.id == stateID }) {
                stateInspector(state: state, editor: editor)
            } else {
                emptySelectionInspector(editor: editor)
            }

        case .transition(let transitionID):
            if let transition = editor.document.definition.transitions.first(where: { $0.id == transitionID }) {
                transitionInspector(transition: transition, editor: editor)
            } else {
                emptySelectionInspector(editor: editor)
            }

        case nil:
            emptySelectionInspector(editor: editor)
        }
    }

    private func stateInspector(
        state: StateDefinition,
        editor: StateMachineEditorSession
    ) -> some View {
        let definition = editor.document.definition

        return VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            EditorPanelSection(
                title: "Selected State",
                description: "State cards represent nodes on the graph and define the payload available while the machine is in that state."
            ) {
                StateTitleEditorView(
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

                StatePropertiesEditorView(state: state)
                    .id(state.id)
            }
        }
    }

    private func transitionInspector(
        transition: TransitionDefinition,
        editor: StateMachineEditorSession
    ) -> some View {
        let definition = editor.document.definition

        return VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            EditorPanelSection(
                title: "Selected Transition",
                description: "Transitions respond to an event and can attach guard and effect references."
            ) {
                TransitionEventEditorView(
                    transition: transition,
                    events: definition.events
                )
                .id("event-\(transition.id)")

                Divider()

                TransitionGuardEditorView(
                    transition: transition,
                    reusableGuards: definition.reusableGuardOptions(excluding: transition.id)
                )
                .id("guard-\(transition.id)")

                Divider()

                TransitionEffectsEditorView(
                    transition: transition,
                    reusableEffects: definition.reusableEffectOptions(excluding: transition.id)
                )
                .id("effects-\(transition.id)")
            }

            EditorPanelSection(
                title: "Transition Routing",
                description: "Route the selected edge between source and target states."
            ) {
                TransitionRoutingEditorView(
                    transition: transition,
                    states: definition.states
                )
            }
        }
    }

    private func emptySelectionInspector(
        editor: StateMachineEditorSession
    ) -> some View {
        return VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            EditorPanelSection(
                title: "How to Use the Graph",
                description: "The shell is diagram-first, so most editing begins on the canvas instead of in a form."
            ) {
                Label("Drag a state card to place it on the graph.", systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Drag from a node handle to another node to create a transition.", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Select an edge to inspect or reassign its event.", systemImage: "slider.horizontal.3")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct TransitionRoutingEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let transition: TransitionDefinition
    let states: [StateDefinition]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Source State") {
                Picker(
                    "Source State",
                    selection: Binding(
                        get: { transition.sourceStateID },
                        set: { newSourceStateID in
                            store.send(
                                .assignSourceStateToTransition(
                                    transitionID: transition.id,
                                    sourceStateID: newSourceStateID
                                )
                            )
                        }
                    )
                ) {
                    ForEach(states) { state in
                        Text(state.name)
                            .tag(state.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            TransitionPickerField(title: "Target State") {
                Picker(
                    "Target State",
                    selection: Binding(
                        get: { transition.targetStateID },
                        set: { newTargetStateID in
                            store.send(
                                .assignTargetStateToTransition(
                                    transitionID: transition.id,
                                    targetStateID: newTargetStateID
                                )
                            )
                        }
                    )
                ) {
                    ForEach(states) { state in
                        Text(state.name)
                            .tag(state.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }
}

private struct TransitionEventEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let transition: TransitionDefinition
    let events: [EventDefinition]

    @State private var newEventName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Current Event") {
                Picker(
                    "Event",
                    selection: Binding(
                        get: { transition.eventID },
                        set: { newEventID in
                            store.send(
                                .assignEventToTransition(
                                    transitionID: transition.id,
                                    eventID: newEventID
                                )
                            )
                        }
                    )
                ) {
                    ForEach(events) { event in
                        Text(event.name)
                            .tag(event.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            TransitionEditorCard {
                Label("Create and Assign", systemImage: "bolt.badge.clock")
                    .font(.subheadline.weight(.semibold))

                TextField("New event name", text: $newEventName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(createEvent)

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Spacer(minLength: 12)

                    Button("Create Event", systemImage: "plus.circle", action: createEvent)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreate)
                }
            }
        }
    }

    private var trimmedNewEventName: String {
        newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedEventNames: Set<String> {
        Set(
            events.map {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }

    private var canCreate: Bool {
        validationMessage == nil && !trimmedNewEventName.isEmpty
    }

    private var validationMessage: String? {
        guard !newEventName.isEmpty else {
            return nil
        }

        if trimmedNewEventName.isEmpty {
            return "The new event needs a name."
        }

        if normalizedEventNames.contains(trimmedNewEventName) {
            return "Event names must stay unique within the machine."
        }

        return nil
    }

    private func createEvent() {
        guard canCreate else {
            return
        }

        store.send(
            .assignNewEventToTransition(
                transitionID: transition.id,
                name: newEventName
            )
        )
        newEventName = ""
    }
}

private struct TransitionPickerField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
    }
}

private struct TransitionGuardEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let transition: TransitionDefinition
    let reusableGuards: [ReusableGuardOption]

    @State private var selectedReusableGuardID = ""
    @State private var guardNameDraft = ""
    @State private var guardDescriptionDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Current Guard") {
                if let guardReference = transition.guard {
                    TransitionAttachedReferenceCard(
                        title: guardReference.name,
                        description: guardReference.description,
                        symbol: "checkmark.shield",
                        tint: .green,
                        removeSymbol: "trash",
                        removeLabel: "Remove Guard"
                    ) {
                        store.send(
                            .removeGuardFromTransition(
                                transitionID: transition.id
                            )
                        )
                    }
                } else {
                    Label("No guard attached yet.", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !reusableGuards.isEmpty {
                TransitionEditorCard {
                    Label("Reuse Existing Guard", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))

                    Picker(
                        "Reusable Guard",
                        selection: Binding(
                            get: { selectedReusableGuard?.id ?? "" },
                            set: { selectedReusableGuardID = $0 }
                        )
                    ) {
                        ForEach(reusableGuards) { reusableGuard in
                            Text(reusableGuard.menuLabel)
                                .tag(reusableGuard.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if let selectedReusableGuard {
                        Text(selectedReusableGuard.sourceSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Spacer(minLength: 12)

                        Button("Reuse Guard", systemImage: "plus.circle") {
                            reuseSelectedGuard()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canReuseSelectedGuard)
                    }
                }
            }

            TransitionEditorCard {
                Label(
                    transition.guard == nil ? "Create Guard" : "Replace Guard",
                    systemImage: "plus.rectangle.on.rectangle"
                )
                .font(.subheadline.weight(.semibold))

                TextField("Guard name", text: $guardNameDraft)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $guardDescriptionDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyDraftGuard)

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Spacer(minLength: 12)

                    Button(
                        transition.guard == nil ? "Add Guard" : "Apply Guard",
                        systemImage: "checkmark.circle",
                        action: applyDraftGuard
                    )
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApplyDraftGuard)
                }
            }
        }
    }

    private var trimmedGuardName: String {
        guardNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedGuardDescription: String {
        guardDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedReusableGuard: ReusableGuardOption? {
        reusableGuards.first(where: { $0.id == selectedReusableGuardID }) ?? reusableGuards.first
    }

    private var draftedGuard: GuardReference {
        GuardReference(
            name: trimmedGuardName,
            description: trimmedGuardDescription.isEmpty ? nil : trimmedGuardDescription
        )
    }

    private var canReuseSelectedGuard: Bool {
        guard let selectedReusableGuard else {
            return false
        }

        return selectedReusableGuard.reference != transition.guard
    }

    private var canApplyDraftGuard: Bool {
        validationMessage == nil && !trimmedGuardName.isEmpty
    }

    private var validationMessage: String? {
        guard !guardNameDraft.isEmpty || !guardDescriptionDraft.isEmpty else {
            return nil
        }

        if trimmedGuardName.isEmpty {
            return "The guard needs a name."
        }

        if draftedGuard == transition.guard {
            return "This guard is already attached to the transition."
        }

        return nil
    }

    private func reuseSelectedGuard() {
        guard let selectedReusableGuard else {
            return
        }

        store.send(
            .assignGuardToTransition(
                transitionID: transition.id,
                guardReference: selectedReusableGuard.reference
            )
        )
    }

    private func applyDraftGuard() {
        guard canApplyDraftGuard else {
            return
        }

        store.send(
            .assignGuardToTransition(
                transitionID: transition.id,
                guardReference: draftedGuard
            )
        )
        guardNameDraft = ""
        guardDescriptionDraft = ""
    }
}

private struct TransitionEffectsEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let transition: TransitionDefinition
    let reusableEffects: [ReusableEffectOption]

    @State private var selectedReusableEffectID = ""
    @State private var effectNameDraft = ""
    @State private var effectDescriptionDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Attached Effects") {
                if transition.effects.isEmpty {
                    Label("No effects attached yet.", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(transition.effects.enumerated()), id: \.offset) { entry in
                            TransitionAttachedReferenceCard(
                                title: entry.element.name,
                                description: entry.element.description,
                                symbol: "sparkles",
                                tint: .orange,
                                removeSymbol: "minus.circle.fill",
                                removeLabel: "Remove Effect"
                            ) {
                                store.send(
                                    .removeEffectFromTransition(
                                        transitionID: transition.id,
                                        effectIndex: entry.offset
                                    )
                                )
                            }
                        }
                    }
                }
            }

            if !reusableEffects.isEmpty {
                TransitionEditorCard {
                    Label("Reuse Existing Effect", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))

                    Picker(
                        "Reusable Effect",
                        selection: Binding(
                            get: { selectedReusableEffect?.id ?? "" },
                            set: { selectedReusableEffectID = $0 }
                        )
                    ) {
                        ForEach(reusableEffects) { reusableEffect in
                            Text(reusableEffect.menuLabel)
                                .tag(reusableEffect.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if let selectedReusableEffect {
                        Text(selectedReusableEffect.sourceSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Spacer(minLength: 12)

                        Button("Add Effect", systemImage: "plus.circle") {
                            reuseSelectedEffect()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canReuseSelectedEffect)
                    }
                }
            }

            TransitionEditorCard {
                Label("Create Effect", systemImage: "plus.rectangle.on.folder")
                    .font(.subheadline.weight(.semibold))

                TextField("Effect name", text: $effectNameDraft)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $effectDescriptionDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDraftEffect)

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Spacer(minLength: 12)

                    Button("Add Effect", systemImage: "plus.circle", action: addDraftEffect)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddDraftEffect)
                }
            }
        }
    }

    private var trimmedEffectName: String {
        effectNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEffectDescription: String {
        effectDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedReusableEffect: ReusableEffectOption? {
        reusableEffects.first(where: { $0.id == selectedReusableEffectID }) ?? reusableEffects.first
    }

    private var draftedEffect: EffectReference {
        EffectReference(
            name: trimmedEffectName,
            description: trimmedEffectDescription.isEmpty ? nil : trimmedEffectDescription
        )
    }

    private var canReuseSelectedEffect: Bool {
        selectedReusableEffect != nil
    }

    private var canAddDraftEffect: Bool {
        validationMessage == nil && !trimmedEffectName.isEmpty
    }

    private var validationMessage: String? {
        guard !effectNameDraft.isEmpty || !effectDescriptionDraft.isEmpty else {
            return nil
        }

        if trimmedEffectName.isEmpty {
            return "The effect needs a name."
        }

        if transition.effects.contains(draftedEffect) {
            return "This effect is already attached to the transition."
        }

        return nil
    }

    private func reuseSelectedEffect() {
        guard let selectedReusableEffect else {
            return
        }

        store.send(
            .addEffectToTransition(
                transitionID: transition.id,
                effect: selectedReusableEffect.reference
            )
        )
    }

    private func addDraftEffect() {
        guard canAddDraftEffect else {
            return
        }

        store.send(
            .addEffectToTransition(
                transitionID: transition.id,
                effect: draftedEffect
            )
        )
        effectNameDraft = ""
        effectDescriptionDraft = ""
    }
}

private struct TransitionEditorCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
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

private struct TransitionAttachedReferenceCard: View {
    let title: String
    let description: String?
    let symbol: String
    let tint: Color
    let removeSymbol: String
    let removeLabel: String
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                if let description, !description.isEmpty {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Button(role: .destructive, action: remove) {
                Image(systemName: removeSymbol)
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help(removeLabel)
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

private struct ReusableGuardOption: Identifiable, Hashable {
    let reference: GuardReference
    let sources: [String]

    var id: String {
        [reference.name, reference.description ?? ""].joined(separator: "|")
    }

    var menuLabel: String {
        reference.name
    }

    var sourceSummary: String {
        "Used by " + joinedSources
    }

    private var joinedSources: String {
        if sources.count <= 2 {
            return sources.joined(separator: ", ")
        }

        return "\(sources.count) transitions"
    }
}

private struct ReusableEffectOption: Identifiable, Hashable {
    let reference: EffectReference
    let sources: [String]

    var id: String {
        [reference.name, reference.description ?? ""].joined(separator: "|")
    }

    var menuLabel: String {
        reference.name
    }

    var sourceSummary: String {
        "Used by " + joinedSources
    }

    private var joinedSources: String {
        if sources.count <= 2 {
            return sources.joined(separator: ", ")
        }

        return "\(sources.count) transitions"
    }
}

private struct StateTitleEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let state: StateDefinition
    let siblingNames: [String]

    @State private var nameDraft: String

    init(state: StateDefinition, siblingNames: [String]) {
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
    }

    private var normalizedSiblingNames: Set<String> {
        Set(
            siblingNames.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
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

        store.send(
            .updateStateName(
                stateID: state.id,
                name: nameDraft
            )
        )
    }
}

private struct StatePropertiesEditorView: View {
    @Environment(SwiftMachineStore.self) private var store

    let state: StateDefinition

    @State private var propertyDrafts: [StatePropertyDraft]

    init(state: StateDefinition) {
        self.state = state
        _propertyDrafts = State(
            initialValue: state.properties.map(StatePropertyDraft.init(property:))
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
                        StatePropertyDraftRowView(propertyDraft: $propertyDraft) {
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
                    propertyDrafts = state.properties.map(StatePropertyDraft.init(property:))
                }
                .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Apply Properties", action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
            }
        }
    }

    private var canApply: Bool {
        validationMessage == nil && isDirty
    }

    private var isDirty: Bool {
        propertyDefinitions != state.properties
    }

    private var validationMessage: String? {
        let trimmedPropertyNames = propertyDrafts.map(\.trimmedName)

        if trimmedPropertyNames.contains(where: \.isEmpty) {
            return "Each property row needs a name before the state can be updated."
        }

        if Set(trimmedPropertyNames).count != trimmedPropertyNames.count {
            return "Property names must be unique within a state."
        }

        if let defaultValueValidationMessage = propertyDrafts
            .compactMap(\.defaultValueValidationMessage)
            .first {
            return defaultValueValidationMessage
        }

        return nil
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.map(\.propertyDefinition)
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(
            .updateStateProperties(
                stateID: state.id,
                properties: propertyDefinitions
            )
        )
    }
}

private struct StatePropertyDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var type: PropertyType
    var isOptional: Bool
    var defaultValue: PropertyDefaultValueDraft

    nonisolated init(
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

    nonisolated init(property: PropertyDefinition) {
        self.init(
            id: property.id,
            name: property.name,
            type: property.type,
            isOptional: property.isOptional,
            defaultValue: PropertyDefaultValueDraft(defaultValue: property.defaultValue)
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var propertyDefinition: PropertyDefinition {
        return PropertyDefinition(
            id: id,
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

private struct StatePropertyDraftRowView: View {
    @Binding var propertyDraft: StatePropertyDraft
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Property name", text: $propertyDraft.name)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 12) {
                StatePropertyControlColumn(title: "Type") {
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

                StatePropertyControlColumn(title: "Optional") {
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

private struct StatePropertyControlColumn<Content: View>: View {
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

private extension StateMachineDefinition {
    func reusableGuardOptions(excluding transitionID: String) -> [ReusableGuardOption] {
        var guardSources: [GuardReference: Set<String>] = [:]

        for transition in transitions where transition.id != transitionID {
            guard let guardReference = transition.guard else {
                continue
            }

            guardSources[guardReference, default: []].insert(transitionEditorSummary(for: transition))
        }

        return guardSources
            .map { reference, sources in
                ReusableGuardOption(
                    reference: reference,
                    sources: sources.sorted()
                )
            }
            .sorted { lhs, rhs in
                lhs.reference.name.localizedStandardCompare(rhs.reference.name) == .orderedAscending
            }
    }

    func reusableEffectOptions(excluding transitionID: String) -> [ReusableEffectOption] {
        var effectSources: [EffectReference: Set<String>] = [:]
        let selectedTransitionEffects = Set(
            transitions.first(where: { $0.id == transitionID })?.effects ?? []
        )

        for transition in transitions where transition.id != transitionID {
            for effectReference in transition.effects where !selectedTransitionEffects.contains(effectReference) {
                effectSources[effectReference, default: []].insert(transitionEditorSummary(for: transition))
            }
        }

        return effectSources
            .map { reference, sources in
                ReusableEffectOption(
                    reference: reference,
                    sources: sources.sorted()
                )
            }
            .sorted { lhs, rhs in
                lhs.reference.name.localizedStandardCompare(rhs.reference.name) == .orderedAscending
            }
    }

    private func transitionEditorSummary(for transition: TransitionDefinition) -> String {
        let sourceName = states.first(where: { $0.id == transition.sourceStateID })?.name ?? transition.sourceStateID
        let targetName = states.first(where: { $0.id == transition.targetStateID })?.name ?? transition.targetStateID
        let eventName = events.first(where: { $0.id == transition.eventID })?.name ?? transition.eventID

        return "\(sourceName) -> \(targetName) on \(eventName)"
    }
}
