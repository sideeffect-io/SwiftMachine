//
//  TransitionInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct TransitionInspectorFeatureView: View {
    @Environment(\.transitionInspectorStoreFactory) private var transitionInspectorStoreFactory

    let transitionID: String
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: transitionInspectorStoreFactory.make(
                transitionID: transitionID,
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    @ViewBuilder
    private func content(for store: TransitionInspectorStore) -> some View {
        Group {
            if let transition = store.inspectedTransition,
               let definition = store.definition {
                VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                    EditorPanelSection(
                        title: "Selected Transition",
                        description: "Transitions respond to an event, describe how the target state is created, and can attach guard and effect references."
                    ) {
                        TransitionEventEditorView(
                            store: store,
                            transition: transition,
                            events: definition.events
                        )
                        .id("event-\(transition.id)")

                        Divider()

                        TransitionTargetStateCreationEditorSectionView(
                            store: store,
                            transition: transition,
                            sourceState: definition.states.first(where: { $0.id == transition.sourceStateID }),
                            targetState: definition.states.first(where: { $0.id == transition.targetStateID }),
                            event: definition.events.first(where: { $0.id == transition.eventID })
                        )
                        .id("target-state-creation-\(transition.id)")

                        Divider()

                        TransitionGuardEditorView(
                            store: store,
                            transition: transition,
                            reusableGuards: definition.reusableGuardOptions(excluding: transition.id)
                        )
                        .id("guard-\(transition.id)")

                        Divider()

                        TransitionEffectsEditorView(
                            store: store,
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
                        store: store,
                        transition: transition,
                        states: definition.states
                    )
                    }
                }
            } else {
                EmptySelectionInspectorView()
            }
        }
    }
}

private struct TransitionRoutingEditorView: View {
    let store: TransitionInspectorStore
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
                            store.send(.assignSourceState(newSourceStateID))
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
                            store.send(.assignTargetState(newTargetStateID))
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
    let store: TransitionInspectorStore
    let transition: TransitionDefinition
    let events: [EventDefinition]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Current Event") {
                Picker(
                    "Event",
                    selection: Binding(
                        get: { transition.eventID },
                        set: { newEventID in
                            store.send(.assignEvent(newEventID))
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
                Label("Event Payload", systemImage: "tray.full")
                    .font(.subheadline.weight(.semibold))

                Text(payloadDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let currentEvent {
                    EditorBadge(
                        text: "\(currentEvent.properties.count) payload \(currentEvent.properties.count == 1 ? "property" : "properties")",
                        tint: .orange
                    )
                } else {
                    Label("This transition no longer references a known event. Pick another event above.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var currentEvent: EventDefinition? {
        events.first(where: { $0.id == transition.eventID })
    }

    private var payloadDescription: String {
        guard let currentEvent else {
            return "This transition should reference an existing event. Reassign it from the menu above."
        }

        return "\(currentEvent.name) is reusable across the whole machine. Edit its payload from the palette pane, and every transition using it will update together."
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

private struct TransitionTargetStateCreationEditorSectionView: View {
    let store: TransitionInspectorStore
    let transition: TransitionDefinition
    let sourceState: StateDefinition?
    let targetState: StateDefinition?
    let event: EventDefinition?

    @State private var draft: TransitionTargetStateCreationDraft

    init(
        store: TransitionInspectorStore,
        transition: TransitionDefinition,
        sourceState: StateDefinition?,
        targetState: StateDefinition?,
        event: EventDefinition?
    ) {
        self.store = store
        self.transition = transition
        self.sourceState = sourceState
        self.targetState = targetState
        self.event = event
        _draft = State(
            initialValue: TransitionTargetStateCreationDraft(
                existingCreation: transition.targetStateCreation,
                sourceProperties: sourceState?.properties ?? [],
                eventProperties: event?.properties ?? [],
                targetProperties: targetState?.properties ?? [],
                typeDefinitions: []
            )
        )
    }

    var body: some View {
        TransitionEditorCard {
            Label("Target State Creation", systemImage: "arrowshape.right.circle")
                .font(.subheadline.weight(.semibold))

            if let sourceState,
               let targetState,
               let event {
                TransitionTargetStateCreationEditorView(
                    sourceStateName: sourceState.name,
                    sourceProperties: sourceState.properties,
                    eventName: event.name,
                    eventProperties: event.properties,
                    targetStateName: targetState.name,
                    targetProperties: targetState.properties,
                    typeDefinitions: typeDefinitions,
                    draft: $draft
                )

                HStack {
                    Button("Reset", action: resetDraft)
                        .disabled(!isDirty)

                    Spacer(minLength: 12)

                    Button("Apply Mapping", action: apply)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canApply)
                }
            } else {
                Label("The transition route is incomplete, so the target-state mapping cannot be edited yet.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: resetDraft)
        .onChange(of: contextSignature) { _, _ in
            resetDraft()
        }
    }

    private var canApply: Bool {
        draft.validationMessage == nil && isDirty
    }

    private var isDirty: Bool {
        draft.targetStateCreation != transition.targetStateCreation
    }

    private var contextSignature: TransitionTargetStateCreationEditorContextSignature {
        TransitionTargetStateCreationEditorContextSignature(
            sourceProperties: sourceState?.properties ?? [],
            eventProperties: event?.properties ?? [],
            targetProperties: targetState?.properties ?? [],
            typeDefinitions: typeDefinitions,
            targetStateCreation: transition.targetStateCreation
        )
    }

    private func resetDraft() {
        draft = TransitionTargetStateCreationDraft(
            existingCreation: transition.targetStateCreation,
            sourceProperties: sourceState?.properties ?? [],
            eventProperties: event?.properties ?? [],
            targetProperties: targetState?.properties ?? [],
            typeDefinitions: typeDefinitions
        )
    }

    private var typeDefinitions: [PayloadTypeDefinition] {
        store.definition?.types ?? []
    }

    private func apply() {
        guard canApply else {
            return
        }

        store.send(.updateTargetStateCreation(draft.targetStateCreation))
    }
}

private struct TransitionTargetStateCreationEditorContextSignature: Equatable {
    let sourceProperties: [PropertyDefinition]
    let eventProperties: [PropertyDefinition]
    let targetProperties: [PropertyDefinition]
    let typeDefinitions: [PayloadTypeDefinition]
    let targetStateCreation: TransitionTargetStateCreation
}

private struct TransitionGuardEditorView: View {
    let store: TransitionInspectorStore
    let transition: TransitionDefinition
    let reusableGuards: [ReusableGuardOption]

    @State private var selectedReusableGuardID = ""
    @State private var guardNameDraft: String
    @State private var guardDescriptionDraft: String

    init(
        store: TransitionInspectorStore,
        transition: TransitionDefinition,
        reusableGuards: [ReusableGuardOption]
    ) {
        self.store = store
        self.transition = transition
        self.reusableGuards = reusableGuards
        _guardNameDraft = State(initialValue: transition.guard?.name ?? "")
        _guardDescriptionDraft = State(initialValue: transition.guard?.description ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TransitionPickerField(title: "Current Guard") {
                TransitionEditorCard {
                    currentGuardSummary

                    Divider()

                    Label(
                        transition.guard == nil ? "Create Guard" : "Edit Details",
                        systemImage: transition.guard == nil ? "plus.rectangle.on.rectangle" : "square.and.pencil"
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
                        Button("Reset", action: resetDraft)
                            .disabled(!isDirty)

                        Spacer(minLength: 12)

                        Button(
                            transition.guard == nil ? "Add Guard" : "Save Guard",
                            systemImage: "checkmark.circle",
                            action: applyDraftGuard
                        )
                        .buttonStyle(.borderedProminent)
                        .disabled(!canApplyDraftGuard)
                    }
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

        }
        .onAppear(perform: resetDraft)
        .onChange(of: transition.guard) { _, _ in
            resetDraft()
        }
    }

    @ViewBuilder
    private var currentGuardSummary: some View {
        if let guardReference = transition.guard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Attached Guard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(guardReference.name)
                        .font(.body.weight(.semibold))

                    if let description = guardReference.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    store.send(.removeGuard)
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .help("Remove Guard")
            }
        } else {
            Label("No guard attached yet. Create one below.", systemImage: "checkmark.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private var isDirty: Bool {
        trimmedGuardName != (transition.guard?.name ?? "")
            || trimmedGuardDescription != (transition.guard?.description ?? "")
    }

    private var canReuseSelectedGuard: Bool {
        guard let selectedReusableGuard else {
            return false
        }

        return selectedReusableGuard.reference != transition.guard
    }

    private var canApplyDraftGuard: Bool {
        validationMessage == nil && !trimmedGuardName.isEmpty && isDirty
    }

    private var validationMessage: String? {
        guard isDirty else {
            return nil
        }

        if trimmedGuardName.isEmpty {
            return "The guard needs a name."
        }

        return nil
    }

    private func reuseSelectedGuard() {
        guard let selectedReusableGuard else {
            return
        }

        store.send(.assignGuard(selectedReusableGuard.reference))
    }

    private func applyDraftGuard() {
        guard canApplyDraftGuard else {
            return
        }

        store.send(.assignGuard(draftedGuard))
    }

    private func resetDraft() {
        guardNameDraft = transition.guard?.name ?? ""
        guardDescriptionDraft = transition.guard?.description ?? ""
    }
}

private struct TransitionEffectsEditorView: View {
    let store: TransitionInspectorStore
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
                            AttachedTransitionEffectEditorView(
                                store: store,
                                transitionID: transition.id,
                                effectIndex: entry.offset,
                                effect: entry.element,
                                siblingEffects: transition.effects.enumerated().compactMap { offset, effect in
                                    offset == entry.offset ? nil : effect
                                }
                            )
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

                        Button("Reuse Effect", systemImage: "plus.circle") {
                            reuseSelectedEffect()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canReuseSelectedEffect)
                    }
                }
            }

            TransitionEditorCard {
                Label("Create New Effect", systemImage: "plus.rectangle.on.folder")
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
        guard let selectedReusableEffect else {
            return false
        }

        return !transition.effects.contains(selectedReusableEffect.reference)
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

        store.send(.addEffect(selectedReusableEffect.reference))
    }

    private func addDraftEffect() {
        guard canAddDraftEffect else {
            return
        }

        store.send(.addEffect(draftedEffect))
        effectNameDraft = ""
        effectDescriptionDraft = ""
    }
}

private struct AttachedTransitionEffectEditorView: View {
    let store: TransitionInspectorStore
    let transitionID: String
    let effectIndex: Int
    let effect: EffectReference
    let siblingEffects: [EffectReference]

    @State private var effectNameDraft: String
    @State private var effectDescriptionDraft: String

    init(
        store: TransitionInspectorStore,
        transitionID: String,
        effectIndex: Int,
        effect: EffectReference,
        siblingEffects: [EffectReference]
    ) {
        self.store = store
        self.transitionID = transitionID
        self.effectIndex = effectIndex
        self.effect = effect
        self.siblingEffects = siblingEffects
        _effectNameDraft = State(initialValue: effect.name)
        _effectDescriptionDraft = State(initialValue: effect.description ?? "")
    }

    var body: some View {
        TransitionEditorCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Attached Effect")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(effect.name)
                        .font(.body.weight(.semibold))

                    if let description = effect.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    store.send(.removeEffect(index: effectIndex))
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .help("Remove Effect")
            }

            Divider()

            Label("Edit Details", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))

            TextField("Effect name", text: $effectNameDraft)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $effectDescriptionDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveEffect)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset", action: resetDraft)
                    .disabled(!isDirty)

                Spacer(minLength: 12)

                Button("Save Effect", systemImage: "checkmark.circle", action: saveEffect)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .onAppear(perform: resetDraft)
        .onChange(of: effect) { _, _ in
            resetDraft()
        }
    }

    private var trimmedEffectName: String {
        effectNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEffectDescription: String {
        effectDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftedEffect: EffectReference {
        EffectReference(
            name: trimmedEffectName,
            description: trimmedEffectDescription.isEmpty ? nil : trimmedEffectDescription
        )
    }

    private var isDirty: Bool {
        trimmedEffectName != effect.name
            || trimmedEffectDescription != (effect.description ?? "")
    }

    private var canSave: Bool {
        validationMessage == nil && !trimmedEffectName.isEmpty && isDirty
    }

    private var validationMessage: String? {
        guard isDirty else {
            return nil
        }

        if trimmedEffectName.isEmpty {
            return "The effect needs a name."
        }

        if normalizedSiblingEffectSignatures.contains(effectSignature(for: draftedEffect)) {
            return "This effect is already attached to the transition."
        }

        return nil
    }

    private var normalizedSiblingEffectSignatures: Set<String> {
        Set(siblingEffects.map(effectSignature(for:)))
    }

    private func effectSignature(for effect: EffectReference) -> String {
        let trimmedName = effect.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = effect.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        return [trimmedName, trimmedDescription?.isEmpty == true ? "" : (trimmedDescription ?? "")]
            .joined(separator: "|")
    }

    private func saveEffect() {
        guard canSave else {
            return
        }

        store.send(.updateEffect(index: effectIndex, effect: draftedEffect))
    }

    private func resetDraft() {
        effectNameDraft = effect.name
        effectDescriptionDraft = effect.description ?? ""
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
