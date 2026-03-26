//
//  TransitionComposerView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct TransitionComposerView: View {
    @Environment(\.transitionComposerStoreFactory) private var transitionComposerStoreFactory

    let prompt: StateMachineTransitionPrompt
    let events: [EventDefinition]
    let sourceState: StateDefinition?
    let targetState: StateDefinition?
    let availableModelTypes: [PayloadTypeDefinition]
    let sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor

    @State private var mode: TransitionPromptMode = .createNew
    @State private var selectedEventID = ""
    @State private var existingEventPropertyDrafts: [EditorPropertyDraft] = []
    @State private var newEventName = ""
    @State private var newEventPropertyDrafts: [EditorPropertyDraft] = []
    @State private var targetStateCreationDraft: TransitionTargetStateCreationDraft

    init(
        prompt: StateMachineTransitionPrompt,
        events: [EventDefinition],
        sourceState: StateDefinition?,
        targetState: StateDefinition?,
        availableModelTypes: [PayloadTypeDefinition],
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) {
        self.prompt = prompt
        self.events = events
        self.sourceState = sourceState
        self.targetState = targetState
        self.availableModelTypes = availableModelTypes
        self.sendEditorCanvasEvent = sendEditorCanvasEvent
        _targetStateCreationDraft = State(
            initialValue: TransitionTargetStateCreationDraft(
                existingCreation: .init(),
                sourceProperties: sourceState?.properties ?? [],
                eventProperties: [],
                targetProperties: targetState?.properties ?? [],
                typeDefinitions: availableModelTypes
            )
        )
    }

    var body: some View {
        WithViewStore(
            store: transitionComposerStoreFactory.make(
                prompt: prompt,
                sendEditorCanvasEvent: sendEditorCanvasEvent
            )
        ) { store in
            content(for: store)
        }
    }

    private func content(for store: TransitionComposerStore) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Create Transition", systemImage: "arrow.triangle.branch")
                    .font(.headline)

                Text("\(sourceState?.name ?? prompt.sourceStateID) -> \(targetState?.name ?? prompt.targetStateID)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !events.isEmpty {
                    Picker("Assignment", selection: $mode) {
                        ForEach(TransitionPromptMode.availableModes(hasExistingEvents: !events.isEmpty)) { option in
                            Text(option.label)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .useExisting, !events.isEmpty {
                    Picker("Event", selection: $selectedEventID) {
                        ForEach(events) { event in
                            Text(event.name)
                                .tag(event.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Payload edits are applied to the reusable event definition before the transition is created.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if existingEventPropertyDrafts.isEmpty {
                        Label("No payload properties yet. Add one if this event should carry typed data.", systemImage: "rectangle.stack.badge.plus")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach($existingEventPropertyDrafts) { $propertyDraft in
                                EditorPropertyDraftRowView(
                                    propertyDraft: $propertyDraft,
                                    availableModelTypes: availableModelTypes,
                                    layout: .paletteInline
                                ) {
                                    removeExistingEventProperty(propertyDraft.id)
                                }
                            }
                        }
                    }

                    Button("Add Property", systemImage: "plus.circle") {
                        existingEventPropertyDrafts.append(.init())
                    }
                } else {
                    TextField("Event name", text: $newEventName)
                        .textFieldStyle(.roundedBorder)

                    if newEventPropertyDrafts.isEmpty {
                        Label("No payload properties yet. Add one if the new event should carry typed data.", systemImage: "rectangle.stack.badge.plus")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach($newEventPropertyDrafts) { $propertyDraft in
                                EditorPropertyDraftRowView(
                                    propertyDraft: $propertyDraft,
                                    availableModelTypes: availableModelTypes,
                                    layout: .paletteInline
                                ) {
                                    removeNewEventProperty(propertyDraft.id)
                                }
                            }
                        }
                    }

                    Button("Add Property", systemImage: "plus.circle") {
                        newEventPropertyDrafts.append(.init())
                    }
                }

                if let sourceState,
                   let targetState {
                    Divider()

                    Label("Target State Creation", systemImage: "arrowshape.right.circle")
                        .font(.subheadline.weight(.semibold))

                    TransitionTargetStateCreationEditorView(
                        sourceStateName: sourceState.name,
                        sourceProperties: sourceState.properties,
                        eventName: activeEventName,
                        eventProperties: activeEventProperties,
                        targetStateName: targetState.name,
                        targetProperties: targetState.properties,
                        typeDefinitions: availableModelTypes,
                        draft: $targetStateCreationDraft
                    )
                }

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Cancel") {
                        store.send(.cancelRequested)
                    }

                    Spacer()

                    Button("Create Transition") {
                        if mode == .useExisting {
                            store.send(
                                .confirmWithExistingEvent(
                                    eventID: selectedEventID,
                                    properties: existingEventProperties,
                                    targetStateCreation: targetStateCreationDraft.targetStateCreation
                                )
                            )
                        } else {
                            store.send(
                                .confirmWithNewEvent(
                                    name: newEventName,
                                    properties: newEventProperties,
                                    targetStateCreation: targetStateCreationDraft.targetStateCreation
                                )
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConfirm)
                }
            }
        }
        .padding(18)
        .frame(width: TransitionComposerMetrics.promptWidth, alignment: .leading)
        .frame(maxHeight: TransitionComposerMetrics.promptHeight)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .onAppear {
            configureDefaults()
        }
        .onChange(of: selectedEventID) { _, _ in
            resetExistingEventDrafts()
            refreshTargetStateCreationDraft()
        }
        .onChange(of: existingEventPropertyDrafts) { _, _ in
            refreshTargetStateCreationDraft()
        }
        .onChange(of: newEventPropertyDrafts) { _, _ in
            refreshTargetStateCreationDraft()
        }
        .onChange(of: mode) { _, _ in
            refreshTargetStateCreationDraft()
        }
    }

    private var canConfirm: Bool {
        if mode == .useExisting {
            return !selectedEventID.isEmpty && validationMessage == nil
        }

        return !trimmedNewEventName.isEmpty && validationMessage == nil
    }

    private var selectedEvent: EventDefinition? {
        events.first(where: { $0.id == selectedEventID })
    }

    private var activeEventName: String {
        if mode == .useExisting {
            return selectedEvent?.name ?? "Event"
        }

        return trimmedNewEventName.isEmpty ? "New Event" : trimmedNewEventName
    }

    private var trimmedNewEventName: String {
        newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedEventNames: Set<String> {
        Set(events.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private var existingEventProperties: [PropertyDefinition] {
        existingEventPropertyDrafts.propertyDefinitions
    }

    private var newEventProperties: [PropertyDefinition] {
        newEventPropertyDrafts.propertyDefinitions
    }

    private var activeEventProperties: [PropertyDefinition] {
        mode == .useExisting ? existingEventProperties : newEventProperties
    }

    private var validationMessage: String? {
        if mode == .useExisting {
            if let eventValidationMessage = existingEventPropertyDrafts.validationMessage(
                emptyNameMessage: "Each property row needs a name before the event can be used.",
                duplicateNameMessage: "Property names must be unique within an event."
            ) {
                return eventValidationMessage
            }

            return targetStateCreationDraft.validationMessage
        }

        guard !newEventName.isEmpty else {
            if let eventValidationMessage = newEventPropertyDrafts.validationMessage(
                emptyNameMessage: "Each property row needs a name before the event can be created.",
                duplicateNameMessage: "Property names must be unique within an event."
            ) {
                return eventValidationMessage
            }

            return targetStateCreationDraft.validationMessage
        }

        if trimmedNewEventName.isEmpty {
            return "The new event needs a name."
        }

        if normalizedEventNames.contains(trimmedNewEventName) {
            return "Event names must stay unique within the machine."
        }

        if let eventValidationMessage = newEventPropertyDrafts.validationMessage(
            emptyNameMessage: "Each property row needs a name before the event can be created.",
            duplicateNameMessage: "Property names must be unique within an event."
        ) {
            return eventValidationMessage
        }

        return targetStateCreationDraft.validationMessage
    }

    private func configureDefaults() {
        if events.isEmpty {
            mode = .createNew
            return
        }

        if selectedEventID.isEmpty {
            selectedEventID = events[0].id
        }

        if mode == .createNew && !events.isEmpty && newEventName.isEmpty {
            mode = .useExisting
        }

        resetExistingEventDrafts()
        refreshTargetStateCreationDraft()
    }

    private func resetExistingEventDrafts() {
        existingEventPropertyDrafts = selectedEvent?.properties.map { property in
            EditorPropertyDraft(
                property: property,
                availableModelTypes: availableModelTypes
            )
        } ?? []
    }

    private func removeExistingEventProperty(_ id: String) {
        existingEventPropertyDrafts.removeAll { $0.id == id }
    }

    private func removeNewEventProperty(_ id: String) {
        newEventPropertyDrafts.removeAll { $0.id == id }
    }

    private func refreshTargetStateCreationDraft() {
        targetStateCreationDraft = TransitionTargetStateCreationDraft(
            existingCreation: targetStateCreationDraft.targetStateCreation,
            sourceProperties: sourceState?.properties ?? [],
            eventProperties: activeEventProperties,
            targetProperties: targetState?.properties ?? [],
            typeDefinitions: availableModelTypes
        )
    }
}

private enum TransitionPromptMode: String, CaseIterable, Identifiable {
    case useExisting
    case createNew

    var id: String { rawValue }

    var label: String {
        switch self {
        case .useExisting:
            return "Existing"
        case .createNew:
            return "New"
        }
    }

    static func availableModes(hasExistingEvents: Bool) -> [TransitionPromptMode] {
        hasExistingEvents ? [.useExisting, .createNew] : [.createNew]
    }
}

private enum TransitionComposerMetrics {
    static let promptWidth: CGFloat = 360
    static let promptHeight: CGFloat = 520
}
