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
    @State private var propertyDrafts: [InitialStatePropertyDraft] = []
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
                            PropertyDraftRowView(propertyDraft: $propertyDraft) {
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
        let trimmedPropertyNames = propertyDrafts.map(\.trimmedName)

        if trimmedPropertyNames.contains(where: \.isEmpty) {
            return "Each property row needs a name before the machine can be created."
        }

        if Set(trimmedPropertyNames).count != trimmedPropertyNames.count {
            return "Property names must be unique within the initial state."
        }

        if let defaultValueValidationMessage = propertyDrafts
            .compactMap(\.defaultValueValidationMessage)
            .first {
            return defaultValueValidationMessage
        }

        return nil
    }

    private var trimmedInitialStateName: String {
        initialStateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.map(\.propertyDefinition)
    }

    private func removeProperty(_ id: UUID) {
        propertyDrafts.removeAll { $0.id == id }
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
                properties: propertyDefinitions
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

private struct InitialStatePropertyDraft: Identifiable {
    let id = UUID()
    var name = ""
    var type: PropertyType = .string
    var isOptional = false
    var defaultValue = PropertyDefaultValueDraft()

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

private struct PropertyDraftRowView: View {
    @Binding var propertyDraft: InitialStatePropertyDraft
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                TextField("Property name", text: $propertyDraft.name)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $propertyDraft.type) {
                    ForEach(PropertyType.allCases, id: \.self) { propertyType in
                        Text(propertyType.rawValue.capitalized)
                            .tag(propertyType)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                Toggle("Optional", isOn: $propertyDraft.isOptional)
                    .toggleStyle(.switch)

                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Remove property")
            }

            PropertyDefaultValueEditor(
                type: propertyDraft.type,
                draft: $propertyDraft.defaultValue,
                layout: .inline
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
