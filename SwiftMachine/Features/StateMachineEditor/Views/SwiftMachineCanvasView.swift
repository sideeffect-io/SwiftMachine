//
//  SwiftMachineCanvasView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineCanvasView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        switch store.state {
        case .designing(let editor):
            SwiftMachineGraphCanvasView(editor: editor)

        case .empty, .drafting:
            wizardSurface
        }
    }

    private var wizardSurface: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            WizardGridBackground()

            phaseContent
                .padding(SwiftMachineShellMetrics.canvasInset)
        }
        .overlay {
            RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                .padding(SwiftMachineShellMetrics.canvasInset / 2)
        }
        .clipped()
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch store.state {
        case .empty:
            wizardLayout(
                title: "Create a State Machine",
                subtitle: "Start by naming the machine."
            ) {
                MachineDraftStepView()
            }

        case .drafting(let machineName):
            wizardLayout(
                title: "Create the Initial State",
                subtitle: nil
            ) {
                InitialStateSetupStepView(machineName: machineName)
                    .id(machineName)
            }

        case .designing:
            EmptyView()
        }
    }

    private func wizardLayout<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: SwiftMachineShellMetrics.panelSpacing) {
            canvasHeader(title: title, subtitle: subtitle)
            Spacer()
            content()
            Spacer()
        }
    }

    private func canvasHeader(title: String, subtitle: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

private struct WizardGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let minorPath = gridPath(in: size, step: SwiftMachineShellMetrics.gridStep)
            let majorPath = gridPath(
                in: size,
                step: SwiftMachineShellMetrics.gridStep * CGFloat(SwiftMachineShellMetrics.majorGridFrequency)
            )

            context.stroke(minorPath, with: .color(Color.primary.opacity(0.045)), lineWidth: 0.5)
            context.stroke(majorPath, with: .color(Color.primary.opacity(0.08)), lineWidth: 0.8)
        }
    }

    private func gridPath(in size: CGSize, step: CGFloat) -> Path {
        var path = Path()
        var x: CGFloat = 0
        var y: CGFloat = 0

        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }

        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }

        return path
    }
}

#Preview {
    SwiftMachineCanvasView()
        .environment(SwiftMachineStore())
        .frame(width: 900, height: 700)
}

#Preview("Drafting") {
    SwiftMachineCanvasView()
        .environment(
            SwiftMachineStore.make(
                initialState: .drafting(name: "Checkout")
            )
        )
        .frame(width: 900, height: 700)
}

#Preview("Designing") {
    SwiftMachineCanvasView()
        .environment(
            SwiftMachineStore.make(
                initialState: .designing(
                    editor: .bootstrap(definition: .makeNew(
                        name: "Checkout",
                        initialStateName: "Idle",
                        initialStateProperties: []
                    )!)
                )
            )
        )
        .frame(width: 900, height: 700)
}

private struct MachineDraftStepView: View {
    @Environment(SwiftMachineStore.self) private var store
    @State private var machineName = ""
    @FocusState private var isMachineNameFocused: Bool

    var body: some View {
        WizardCard(
            symbol: "square.and.pencil",
            title: "Name the Machine",
            description: nil
        ) {
            TextField("Checkout Flow", text: $machineName)
                .textFieldStyle(.roundedBorder)
                .focused($isMachineNameFocused)
                .defaultFocus($isMachineNameFocused, true)
                .onSubmit(submit)

            Button("Continue", systemImage: "arrow.right.circle.fill", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedMachineName.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .task {
            await Task.yield()
            isMachineNameFocused = true
        }
    }

    private var trimmedMachineName: String {
        machineName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedMachineName.isEmpty else {
            isMachineNameFocused = true
            return
        }

        isMachineNameFocused = false
        store.send(.createEmptyStateMachine(name: machineName))
    }
}

private struct InitialStateSetupStepView: View {
    @Environment(SwiftMachineStore.self) private var store

    let machineName: String

    @State private var initialStateName = ""
    @State private var typeDrafts: [InitialStateTypeDraft] = []
    @State private var propertyDrafts: [EditorPropertyDraft] = []
    @FocusState private var isInitialStateNameFocused: Bool

    var body: some View {
        WizardCard(
            symbol: "circle.hexagongrid",
            title: "Define the Initial State",
            description: nil
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Machine")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(machineName)
                    .font(.title3.weight(.semibold))
            }

            Divider()

            TextField("Initial state name", text: $initialStateName)
                .textFieldStyle(.roundedBorder)
                .focused($isInitialStateNameFocused)
                .defaultFocus($isInitialStateNameFocused, true)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reusable Types")
                            .font(.headline)

                        Text("Define reusable structs and enums here first, then assign them to the initial state's payload properties.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button("Add Struct", systemImage: "square.on.square") {
                            addStructType()
                        }

                        Button("Add Enum", systemImage: "list.bullet.rectangle") {
                            addEnumType()
                        }
                    }
                }

                if typeDrafts.isEmpty {
                    Label("No reusable types yet. Add one when the initial state needs a composed payload.", systemImage: "square.stack.3d.up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach($typeDrafts) { $typeDraft in
                            InitialStateTypeDraftView(
                                typeDraft: $typeDraft,
                                availableModelTypes: availableModelTypes(excluding: typeDraft.id),
                                canRemove: !typeIsReferenced(typeDraft.id)
                            ) {
                                removeType(typeDraft.id)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Initial State Properties")
                            .font(.headline)
                    }

                    Spacer()

                    Button("Add Property", systemImage: "plus.circle") {
                        propertyDrafts.append(.init())
                    }
                }

                if propertyDrafts.isEmpty {
                    Label("No properties yet. Add one only if the initial state needs typed data.", systemImage: "rectangle.stack.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach($propertyDrafts) { $propertyDraft in
                            EditorPropertyDraftRowView(
                                propertyDraft: $propertyDraft,
                                availableModelTypes: typeDefinitions,
                                layout: .adaptiveInline
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
            }

            Button("Enter the Editor", systemImage: "sparkles.rectangle.stack", action: submit)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onSubmit(submit)
        .task(id: machineName) {
            await Task.yield()
            isInitialStateNameFocused = true
        }
    }

    private var canSubmit: Bool {
        !trimmedInitialStateName.isEmpty && validationMessage == nil
    }

    private var validationMessage: String? {
        if let propertyValidationMessage = propertyDrafts.validationMessage(
            emptyNameMessage: "Each property row needs a name before the machine can be created.",
            duplicateNameMessage: "Property names must be unique within the initial state."
        ) {
            return propertyValidationMessage
        }

        let placeholderStateName = trimmedInitialStateName.isEmpty ? "Initial State" : trimmedInitialStateName
        let draftMachine = StateMachineDefinition(
            id: "initial-state-draft",
            name: machineName,
            initialStateID: "initial-state",
            types: typeDefinitions,
            states: [
                StateDefinition(
                    id: "initial-state",
                    name: placeholderStateName,
                    properties: propertyDefinitions
                )
            ],
            events: [],
            transitions: []
        )

        return draftMachine.validate()
            .compactMap(wizardValidationMessage(for:))
            .first
    }

    private var trimmedInitialStateName: String {
        initialStateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.propertyDefinitions
    }

    private var typeDefinitions: [PayloadTypeDefinition] {
        typeDrafts.map(\.typeDefinition)
    }

    private func availableModelTypes(excluding typeID: String) -> [PayloadTypeDefinition] {
        typeDefinitions.filter { $0.id != typeID }
    }

    private func removeProperty(_ id: String) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func addStructType() {
        typeDrafts.append(
            .structType(
                name: suggestedTypeName(prefix: "Struct"),
                fields: []
            )
        )
    }

    private func addEnumType() {
        typeDrafts.append(
            .enumType(
                name: suggestedTypeName(prefix: "Enum"),
                cases: [],
                defaultCaseID: nil
            )
        )
    }

    private func removeType(_ typeID: String) {
        guard !typeIsReferenced(typeID) else {
            return
        }

        typeDrafts.removeAll { $0.id == typeID }
    }

    private func typeIsReferenced(_ typeID: String) -> Bool {
        if propertyDrafts.contains(where: { $0.type.referencedTypeID == typeID }) {
            return true
        }

        return typeDrafts.contains { draft in
            guard draft.id != typeID else {
                return false
            }

            return draft.referencesType(typeID)
        }
    }

    private func suggestedTypeName(prefix: String) -> String {
        let existingNames = Set(
            typeDrafts.map {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )

        var index = 1
        while existingNames.contains("\(prefix) \(index)") {
            index += 1
        }

        return "\(prefix) \(index)"
    }

    private func wizardValidationMessage(
        for error: StateMachineDefinition.ValidationError
    ) -> String? {
        switch error {
        case .emptyTypeName:
            return "Each reusable type needs a name before the machine can be created."
        case .duplicateTypeName:
            return "Reusable type names must be unique within the machine."
        case .duplicateTypePropertyName:
            return "Field names must be unique within a reusable struct."
        case .emptyTypeCaseName:
            return "Each enum case needs a name before the machine can be created."
        case .duplicateTypeCaseName:
            return "Case names must be unique within a reusable enum."
        case .unknownTypeDefaultCase:
            return "The selected default enum case must still exist."
        case .unknownPropertyTypeReference:
            return "One or more properties reference a missing reusable type."
        case .recursiveTypeReference:
            return "Reusable types cannot reference themselves recursively."
        default:
            return nil
        }
    }

    private func submit() {
        guard canSubmit else {
            if trimmedInitialStateName.isEmpty {
                isInitialStateNameFocused = true
            }
            return
        }

        isInitialStateNameFocused = false
        store.send(
            .setInitialState(
                name: initialStateName,
                properties: propertyDefinitions,
                types: typeDefinitions
            )
        )
    }
}

private struct WizardCard<Content: View>: View {
    let symbol: String
    let title: String
    let description: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: symbol)
                .font(.title2.weight(.semibold))

            if let description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

private struct InitialStateTypeDraft: Identifiable, Equatable {
    enum Kind: Equatable {
        case structType(fields: [EditorPropertyDraft])
        case enumType(cases: [InitialStateEnumCaseDraft], defaultCaseID: String?)
    }

    let id: String
    var name: String
    var kind: Kind

    nonisolated init(
        id: String = UUID().uuidString,
        name: String,
        kind: Kind
    ) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    nonisolated static func structType(
        name: String,
        fields: [EditorPropertyDraft]
    ) -> InitialStateTypeDraft {
        InitialStateTypeDraft(
            name: name,
            kind: .structType(fields: fields)
        )
    }

    nonisolated static func enumType(
        name: String,
        cases: [InitialStateEnumCaseDraft],
        defaultCaseID: String?
    ) -> InitialStateTypeDraft {
        InitialStateTypeDraft(
            name: name,
            kind: .enumType(cases: cases, defaultCaseID: defaultCaseID)
        )
    }

    var typeDefinition: PayloadTypeDefinition {
        PayloadTypeDefinition(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: payloadTypeKind
        )
    }

    var kindTitle: String {
        switch kind {
        case .structType:
            return "Struct"
        case .enumType:
            return "Enum"
        }
    }

    func referencesType(_ typeID: String) -> Bool {
        switch kind {
        case .structType(let fields):
            return fields.contains(where: { $0.type.referencedTypeID == typeID })
        case .enumType(let cases, _):
            return cases.contains(where: { $0.payloadType?.referencedTypeID == typeID })
        }
    }

    private var payloadTypeKind: PayloadTypeKind {
        switch kind {
        case .structType(let fields):
            return .structType(fields: fields.propertyDefinitions)
        case .enumType(let cases, let defaultCaseID):
            return .enumType(
                cases: cases.map(\.caseDefinition),
                defaultCaseID: defaultCaseID
            )
        }
    }
}

private struct InitialStateEnumCaseDraft: Identifiable, Equatable {
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

    var caseDefinition: PayloadEnumCaseDefinition {
        PayloadEnumCaseDefinition(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            payloadType: payloadType
        )
    }
}

private struct InitialStateTypeDraftView: View {
    @Binding var typeDraft: InitialStateTypeDraft
    let availableModelTypes: [PayloadTypeDefinition]
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Type name", text: nameBinding)
                        .textFieldStyle(.roundedBorder)

                    EditorBadge(
                        text: typeDraft.kindTitle,
                        tint: kindTint
                    )
                }

                Spacer(minLength: 12)

                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(!canRemove)
                .help(canRemove ? "Remove type" : "This type is still referenced by another property or type.")
            }

            switch kindBinding.wrappedValue {
            case .structType:
                structFieldsEditor
            case .enumType:
                enumCasesEditor
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

    private var nameBinding: Binding<String> {
        Binding(
            get: { typeDraft.name },
            set: { typeDraft.name = $0 }
        )
    }

    private var kindTint: Color {
        switch typeDraft.kind {
        case .structType:
            return .green
        case .enumType:
            return .orange
        }
    }

    private var kindBinding: Binding<InitialStateTypeDraft.Kind> {
        Binding(
            get: { typeDraft.kind },
            set: { typeDraft.kind = $0 }
        )
    }

    @ViewBuilder
    private var structFieldsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Struct Fields")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Add Field", systemImage: "plus.circle") {
                    guard case .structType(let fields) = typeDraft.kind else {
                        return
                    }
                    typeDraft.kind = .structType(fields: fields + [.init()])
                }
            }

            if case .structType(let fields) = typeDraft.kind {
                if fields.isEmpty {
                    Label("No fields yet. Add one to make this struct usable from initial state properties.", systemImage: "rectangle.stack.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(structFieldBindings) { fieldBinding in
                        EditorPropertyDraftRowView(
                            propertyDraft: fieldBinding,
                            availableModelTypes: availableModelTypes,
                            layout: .adaptiveInline
                        ) {
                            removeStructField(fieldBinding.wrappedValue.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var enumCasesEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Enum Cases")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button("Add Case", systemImage: "plus.circle") {
                    guard case .enumType(let cases, let defaultCaseID) = typeDraft.kind else {
                        return
                    }
                    typeDraft.kind = .enumType(
                        cases: cases + [.init()],
                        defaultCaseID: defaultCaseID
                    )
                }
            }

            if case .enumType(let cases, _) = typeDraft.kind {
                if cases.isEmpty {
                    Label("No cases yet. Add one to make this enum selectable from the initial state.", systemImage: "list.bullet.rectangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(enumCaseBindings) { caseBinding in
                        InitialStateEnumCaseDraftRowView(
                            caseDraft: caseBinding,
                            availableModelTypes: availableModelTypes,
                            isDefault: defaultCaseID == caseBinding.wrappedValue.id,
                            onSetDefault: { isEnabled in
                                setDefaultCase(caseBinding.wrappedValue.id, isEnabled: isEnabled)
                            }
                        ) {
                            removeEnumCase(caseBinding.wrappedValue.id)
                        }
                    }
                }
            }
        }
    }

    private var defaultCaseID: String? {
        guard case .enumType(_, let defaultCaseID) = typeDraft.kind else {
            return nil
        }

        return defaultCaseID
    }

    private var structFieldBindings: [Binding<EditorPropertyDraft>] {
        guard case .structType(let fields) = typeDraft.kind else {
            return []
        }

        return fields.indices.map { index in
            Binding(
                get: {
                    guard case .structType(let currentFields) = typeDraft.kind else {
                        return fields[index]
                    }

                    return currentFields[index]
                },
                set: { updatedField in
                    guard case .structType(var currentFields) = typeDraft.kind,
                          currentFields.indices.contains(index) else {
                        return
                    }

                    currentFields[index] = updatedField
                    typeDraft.kind = .structType(fields: currentFields)
                }
            )
        }
    }

    private var enumCaseBindings: [Binding<InitialStateEnumCaseDraft>] {
        guard case .enumType(let cases, _) = typeDraft.kind else {
            return []
        }

        return cases.indices.map { index in
            Binding(
                get: {
                    guard case .enumType(let currentCases, _) = typeDraft.kind else {
                        return cases[index]
                    }

                    return currentCases[index]
                },
                set: { updatedCase in
                    guard case .enumType(var currentCases, let defaultCaseID) = typeDraft.kind,
                          currentCases.indices.contains(index) else {
                        return
                    }

                    currentCases[index] = updatedCase
                    typeDraft.kind = .enumType(
                        cases: currentCases,
                        defaultCaseID: defaultCaseID
                    )
                }
            )
        }
    }

    private func removeStructField(_ fieldID: String) {
        guard case .structType(let fields) = typeDraft.kind else {
            return
        }

        typeDraft.kind = .structType(
            fields: fields.filter { $0.id != fieldID }
        )
    }

    private func setDefaultCase(_ caseID: String, isEnabled: Bool) {
        guard case .enumType(let cases, _) = typeDraft.kind else {
            return
        }

        typeDraft.kind = .enumType(
            cases: cases,
            defaultCaseID: isEnabled ? caseID : nil
        )
    }

    private func removeEnumCase(_ caseID: String) {
        guard case .enumType(let cases, let defaultCaseID) = typeDraft.kind else {
            return
        }

        typeDraft.kind = .enumType(
            cases: cases.filter { $0.id != caseID },
            defaultCaseID: defaultCaseID == caseID ? nil : defaultCaseID
        )
    }
}

private struct InitialStateEnumCaseDraftRowView: View {
    @Binding var caseDraft: InitialStateEnumCaseDraft
    let availableModelTypes: [PayloadTypeDefinition]
    let isDefault: Bool
    let onSetDefault: (Bool) -> Void
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
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
