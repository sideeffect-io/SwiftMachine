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
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            CanvasGridBackground()

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
                subtitle: "Start by naming the machine. The reducer stays in `.empty` until a non-empty name is submitted."
            ) {
                MachineDraftStepView()
            }

        case .drafting(let machineName):
            wizardLayout(
                title: "Create the Initial State",
                subtitle: "The editor becomes available only after the initial state has been defined."
            ) {
                InitialStateSetupStepView(machineName: machineName)
                    .id(machineName)
            }

        case .designing(let stateMachine):
            designingLayout(stateMachine: stateMachine)
        }
    }

    private func wizardLayout<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: SwiftMachineShellMetrics.panelSpacing) {
            canvasHeader(title: title, subtitle: subtitle)
            Spacer()
            content()
            Spacer()
        }
    }

    private func designingLayout(stateMachine: StateMachineDefinition) -> some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            canvasHeader(
                title: stateMachine.name,
                subtitle: "The canvas reflects the current in-memory state machine definition. Use the toolbox to add more elements."
            )

            ScrollView {
                DesigningCanvasContentView(stateMachine: stateMachine)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
        }
    }

    private func canvasHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct CanvasGridBackground: View {
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
                    stateMachine: .makeNew(
                        name: "Checkout",
                        initialStateName: "Idle",
                        initialStateProperties: []
                    )!
                )
            )
        )
        .frame(width: 900, height: 700)
}

private struct MachineDraftStepView: View {
    @Environment(SwiftMachineStore.self) private var store
    @State private var machineName = ""

    var body: some View {
        WizardCard(
            symbol: "square.and.pencil",
            title: "Name the Machine",
            description: "This value becomes the canonical `StateMachineDefinition.name` once the initial state is created."
        ) {
            TextField("Checkout Flow", text: $machineName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            Button("Continue", systemImage: "arrow.right.circle.fill", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedMachineName.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var trimmedMachineName: String {
        machineName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !trimmedMachineName.isEmpty else {
            return
        }

        store.send(.createEmptyStateMachine(name: machineName))
    }
}

private struct InitialStateSetupStepView: View {
    @Environment(SwiftMachineStore.self) private var store

    let machineName: String

    @State private var initialStateName = ""
    @State private var propertyDrafts: [InitialStatePropertyDraft] = []

    var body: some View {
        WizardCard(
            symbol: "circle.hexagongrid",
            title: "Define the Initial State",
            description: "This step creates the first valid `StateMachineDefinition` and unlocks the editor."
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
                .onSubmit(submit)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Initial State Properties")
                            .font(.headline)

                        Text("Properties are local wizard inputs and are submitted as full `PropertyDefinition` values.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                .disabled(!canSubmit)
                .frame(maxWidth: .infinity, alignment: .trailing)
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

        return nil
    }

    private var trimmedInitialStateName: String {
        initialStateName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var propertyDefinitions: [PropertyDefinition] {
        propertyDrafts.map {
            PropertyDefinition(
                name: $0.trimmedName,
                type: $0.type,
                isOptional: $0.isOptional
            )
        }
    }

    private func removeProperty(_ id: UUID) {
        propertyDrafts.removeAll { $0.id == id }
    }

    private func submit() {
        guard canSubmit else {
            return
        }

        store.send(
            .setInitialState(
                name: initialStateName,
                properties: propertyDefinitions
            )
        )
    }
}

private struct DesigningCanvasContentView: View {
    let stateMachine: StateMachineDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            MachineSummaryView(stateMachine: stateMachine)

            DefinitionSection(title: "States", description: "The initial state is marked explicitly and its properties are rendered inline.") {
                ForEach(stateMachine.states) { state in
                    DefinitionCard(symbol: "circle.hexagongrid", title: state.name) {
                        if state.id == stateMachine.initialStateID {
                            Badge(text: "Initial State", tint: .green)
                        }

                        if state.properties.isEmpty {
                            Text("No properties")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            PropertyListView(properties: state.properties)
                        }
                    }
                }
            }

            DefinitionSection(title: "Events", description: "Events can be created from the toolbox and will appear here immediately.") {
                if stateMachine.events.isEmpty {
                    EmptyDefinitionCard(
                        title: "No Events Yet",
                        systemImage: "bolt.horizontal.circle",
                        message: "Use the toolbox to create the first event."
                    )
                } else {
                    ForEach(stateMachine.events) { event in
                        DefinitionCard(symbol: "bolt.horizontal.circle", title: event.name) {
                            if event.properties.isEmpty {
                                Text("No payload properties")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                PropertyListView(properties: event.properties)
                            }
                        }
                    }
                }
            }

            DefinitionSection(title: "Transitions", description: "Transition rendering is wired into the canvas now, but creation is held back until selection semantics are defined.") {
                if stateMachine.transitions.isEmpty {
                    EmptyDefinitionCard(
                        title: "No Transitions Yet",
                        systemImage: "arrow.triangle.branch",
                        message: "Transition creation stays disabled until the editor can capture source, event, and target explicitly."
                    )
                } else {
                    ForEach(stateMachine.transitions) { transition in
                        DefinitionCard(symbol: "arrow.triangle.branch", title: transition.id) {
                            Text("\(transition.sourceStateID) --\(transition.eventID)--> \(transition.targetStateID)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.bottom, SwiftMachineShellMetrics.canvasInset)
    }
}

private struct WizardCard<Content: View>: View {
    let symbol: String
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: symbol)
                .font(.title2.weight(.semibold))

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

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

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct MachineSummaryView: View {
    let stateMachine: StateMachineDefinition

    var body: some View {
        HStack(spacing: 12) {
            Badge(text: "\(stateMachine.states.count) state\(stateMachine.states.count == 1 ? "" : "s")", tint: .blue)
            Badge(text: "\(stateMachine.events.count) event\(stateMachine.events.count == 1 ? "" : "s")", tint: .orange)
            Badge(text: "\(stateMachine.transitions.count) transition\(stateMachine.transitions.count == 1 ? "" : "s")", tint: .pink)
            Badge(text: stateMachine.isValid ? "Valid definition" : "Invalid definition", tint: stateMachine.isValid ? .green : .red)
        }
    }
}

private struct DefinitionSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
    }
}

private struct DefinitionCard<Content: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct EmptyDefinitionCard: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PropertyListView: View {
    let properties: [PropertyDefinition]

    var body: some View {
        TagFlowLayout(spacing: 8) {
            ForEach(properties) { property in
                Badge(
                    text: property.label,
                    tint: property.isOptional ? .purple : .blue
                )
            }
        }
    }
}

private struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct TagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let fittingWidth = proposal.width ?? 480
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > fittingWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        totalHeight += currentRowHeight

        return CGSize(width: fittingWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + spacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

private extension PropertyDefinition {
    var label: String {
        "\(name): \(type.rawValue)\(isOptional ? "?" : "")"
    }
}
