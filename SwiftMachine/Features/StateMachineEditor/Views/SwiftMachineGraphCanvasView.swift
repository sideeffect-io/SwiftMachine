//
//  SwiftMachineGraphCanvasView.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct SwiftMachineGraphCanvasView: View {
    @Environment(SwiftMachineStore.self) private var store

    let editor: StateMachineEditorSession

    @State private var canvasScale = GraphCanvasMetrics.defaultZoomScale
    @GestureState private var pinchScale: CGFloat = 1

    var body: some View {
        let currentConnectionSnapTarget = activeConnectionSnapTarget
        let effectiveCanvasScale = clampedCanvasScale(canvasScale * pinchScale)

        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView([.horizontal, .vertical]) {
                graphWorkspace(
                    currentConnectionSnapTarget: currentConnectionSnapTarget,
                    canvasScale: effectiveCanvasScale
                )
                .frame(
                    width: GraphCanvasMetrics.workspaceWidth,
                    height: GraphCanvasMetrics.workspaceHeight,
                    alignment: .topLeading
                )
                .scaleEffect(effectiveCanvasScale, anchor: .topLeading)
                .frame(
                    width: GraphCanvasMetrics.workspaceWidth * effectiveCanvasScale,
                    height: GraphCanvasMetrics.workspaceHeight * effectiveCanvasScale,
                    alignment: .topLeading
                )
                .padding(SwiftMachineShellMetrics.canvasInset)
            }
            .simultaneousGesture(canvasZoomGesture)
            .background(
                RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .underPageBackgroundColor),
                                Color(nsColor: .windowBackgroundColor)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var definition: StateMachineDefinition {
        editor.document.definition
    }

    private var selectedStateID: String? {
        guard case .state(let stateID) = editor.selection else {
            return nil
        }

        return stateID
    }

    private var selectedTransitionID: String? {
        guard case .transition(let transitionID) = editor.selection else {
            return nil
        }

        return transitionID
    }

    private var activeConnectionSnapTarget: ConnectionSnapTarget? {
        guard let connectionDraft = editor.connectionDraft else {
            return nil
        }

        return editor.snapTarget(
            for: connectionDraft.currentLocation,
            excluding: connectionDraft.sourceStateID
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(definition.name)
                    .font(.title3.weight(.semibold))

                Text("Drag states to position them. Drag from a node handle to create a transition. Pinch to zoom the canvas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            EditorBadge(text: "\(definition.states.count) states", tint: .blue)
            EditorBadge(text: "\(definition.transitions.count) transitions", tint: .orange)
        }
    }

    @ViewBuilder
    private func graphWorkspace(
        currentConnectionSnapTarget: ConnectionSnapTarget?,
        canvasScale: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(
                    width: GraphCanvasMetrics.workspaceWidth,
                    height: GraphCanvasMetrics.workspaceHeight
                )
                .onTapGesture {
                    store.send(.clearSelection)
                }

            GraphCanvasBackground()
                .frame(
                    width: GraphCanvasMetrics.workspaceWidth,
                    height: GraphCanvasMetrics.workspaceHeight
                )

            ForEach(definition.transitions) { transition in
                TransitionEdgeView(
                    transition: transition,
                    editor: editor,
                    eventName: eventName(for: transition.eventID),
                    isSelected: selectedTransitionID == transition.id
                )
                .zIndex(0)
            }

            ForEach(definition.states) { state in
                StateNodeView(
                    state: state,
                    editor: editor,
                    position: editor.document.position(for: state.id),
                    isInitial: state.id == definition.initialStateID,
                    isSelected: selectedStateID == state.id,
                    isConnectionSnapTarget: currentConnectionSnapTarget?.stateID == state.id,
                    canvasScale: canvasScale
                )
                .zIndex(1)
            }

            if let connectionDraft = editor.connectionDraft {
                ConnectionDraftView(
                    sourceAnchor: editor.document.connectionAnchor(for: connectionDraft.sourceStateID).cgPoint,
                    currentLocation: connectionDraft.currentLocation.cgPoint,
                    isSnapped: currentConnectionSnapTarget != nil
                )
                .zIndex(2)
            }

            if let prompt = editor.transitionPrompt {
                TransitionPromptView(
                    prompt: prompt,
                    events: definition.events,
                    sourceName: stateName(for: prompt.sourceStateID),
                    targetName: stateName(for: prompt.targetStateID)
                )
                .id(promptIdentity(prompt))
                .position(promptPosition(for: prompt.anchor))
                .zIndex(3)
            }
        }
    }

    private var canvasZoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                canvasScale = clampedCanvasScale(canvasScale * value)
            }
    }

    private func clampedCanvasScale(_ proposedScale: CGFloat) -> CGFloat {
        min(
            max(proposedScale, GraphCanvasMetrics.minimumZoomScale),
            GraphCanvasMetrics.maximumZoomScale
        )
    }

    private func stateName(for stateID: String) -> String {
        definition.states.first(where: { $0.id == stateID })?.name ?? stateID
    }

    private func eventName(for eventID: String) -> String {
        definition.events.first(where: { $0.id == eventID })?.name ?? eventID
    }

    private func promptIdentity(_ prompt: StateMachineTransitionPrompt) -> String {
        "\(prompt.sourceStateID)|\(prompt.targetStateID)|\(prompt.anchor.x)|\(prompt.anchor.y)"
    }

    private func promptPosition(for anchor: StateMachineEditorPoint) -> CGPoint {
        let halfWidth = GraphCanvasMetrics.promptWidth / 2
        let halfHeight = GraphCanvasMetrics.promptHeight / 2
        let desiredX = CGFloat(anchor.x) + 28
        let desiredY = CGFloat(anchor.y) + 28
        let clampedX = min(
            max(desiredX, halfWidth + 20),
            GraphCanvasMetrics.workspaceWidth - halfWidth - 20
        )
        let clampedY = min(
            max(desiredY, halfHeight + 20),
            GraphCanvasMetrics.workspaceHeight - halfHeight - 20
        )

        return CGPoint(x: clampedX, y: clampedY)
    }
}

private struct GraphCanvasBackground: View {
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

private struct StateNodeView: View {
    @Environment(SwiftMachineStore.self) private var store

    let state: StateDefinition
    let editor: StateMachineEditorSession
    let position: StateMachineEditorPoint
    let isInitial: Bool
    let isSelected: Bool
    let isConnectionSnapTarget: Bool
    let canvasScale: CGFloat

    @State private var dragOrigin: StateMachineEditorPoint?
    @State private var isCreatingConnection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(state.properties.isEmpty ? "No state payload" : "\(state.properties.count) typed propert\(state.properties.count == 1 ? "y" : "ies")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                connectionHandle
            }

            if state.properties.isEmpty {
                Label("Add properties later from the inspector.", systemImage: "rectangle.stack")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                StateNodePropertyStripView(properties: state.properties)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(
            width: GraphCanvasMetrics.nodeWidth,
            height: GraphCanvasMetrics.nodeHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                    lineWidth: isSelected ? 2.5 : 1.5
                )
        }
        .overlay(alignment: .leading) {
            if isInitial {
                InitialStateEntryArrow()
                    .offset(x: -GraphCanvasMetrics.initialStateArrowLength + 2)
            }
        }
        .shadow(color: .black.opacity(isSelected ? 0.14 : 0.08), radius: isSelected ? 16 : 10, y: 8)
        .position(
            x: CGFloat(position.x) + (GraphCanvasMetrics.nodeWidth / 2),
            y: CGFloat(position.y) + (GraphCanvasMetrics.nodeHeight / 2)
        )
        .onTapGesture {
            store.send(.selectState(id: state.id))
        }
        .gesture(nodeDragGesture)
    }

    private var connectionHandle: some View {
        Circle()
            .fill(connectionHandleTint.gradient)
            .frame(
                width: GraphCanvasMetrics.connectionHandleSize,
                height: GraphCanvasMetrics.connectionHandleSize
            )
            .overlay {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay {
                if isConnectionSnapTarget {
                    Circle()
                        .stroke(Color.green.opacity(0.9), lineWidth: 3)
                        .padding(-5)
                }
            }
            .scaleEffect(isConnectionSnapTarget ? 1.08 : 1)
            .shadow(
                color: isConnectionSnapTarget ? Color.green.opacity(0.35) : .clear,
                radius: isConnectionSnapTarget ? 10 : 0
            )
            .help("Drag to create a transition")
            .gesture(connectionGesture)
    }

    private var nodeDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = position
                }

                let basePosition = dragOrigin ?? position
                let translation = normalizedTranslation(for: value.translation)
                let nextPosition = basePosition.translatingBy(
                    dx: Double(translation.width),
                    dy: Double(translation.height)
                )

                store.send(.moveState(id: state.id, to: clamp(nextPosition)))
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private var connectionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let translation = normalizedTranslation(for: value.translation)
                let rawLocation = connectionAnchor.translatingBy(
                    dx: Double(translation.width),
                    dy: Double(translation.height)
                )
                let snappedLocation = snapTarget(for: rawLocation)?.anchor ?? rawLocation

                if !isCreatingConnection {
                    isCreatingConnection = true
                    store.send(.startConnectionDrag(sourceStateID: state.id, location: snappedLocation))
                } else {
                    store.send(.updateConnectionDrag(location: snappedLocation))
                }
            }
            .onEnded { value in
                let translation = normalizedTranslation(for: value.translation)
                let rawDropLocation = connectionAnchor.translatingBy(
                    dx: Double(translation.width),
                    dy: Double(translation.height)
                )
                let snappedTarget = snapTarget(for: rawDropLocation)
                let dropLocation = snappedTarget?.anchor ?? rawDropLocation
                let targetStateID = snappedTarget?.stateID ?? editor.document.stateID(at: rawDropLocation)

                isCreatingConnection = false
                store.send(
                    .completeConnectionDrag(
                        targetStateID: targetStateID,
                        promptLocation: dropLocation
                    )
                )
            }
    }

    private var connectionAnchor: StateMachineEditorPoint {
        editor.document.connectionAnchor(for: state.id)
    }

    private func clamp(_ point: StateMachineEditorPoint) -> StateMachineEditorPoint {
        let maxX = GraphCanvasMetrics.workspaceWidth - GraphCanvasMetrics.nodeWidth
        let maxY = GraphCanvasMetrics.workspaceHeight - GraphCanvasMetrics.nodeHeight

        return StateMachineEditorPoint(
            x: min(max(point.x, 0), Double(maxX)),
            y: min(max(point.y, 0), Double(maxY))
        )
    }

    private var connectionHandleTint: Color {
        if isConnectionSnapTarget {
            return .green
        }

        return isSelected ? .accentColor : .orange
    }

    private func snapTarget(for location: StateMachineEditorPoint) -> ConnectionSnapTarget? {
        editor.snapTarget(for: location, excluding: state.id)
    }

    private func normalizedTranslation(for translation: CGSize) -> CGSize {
        let safeScale = max(canvasScale, .leastNonzeroMagnitude)
        return CGSize(
            width: translation.width / safeScale,
            height: translation.height / safeScale
        )
    }
}

private struct StateNodePropertyStripView: View {
    let properties: [PropertyDefinition]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(properties) { property in
                    EditorBadge(
                        text: property.name,
                        tint: property.isOptional ? .purple : .blue
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InitialStateEntryArrow: View {
    var body: some View {
        ZStack(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.18),
                            Color.green.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: GraphCanvasMetrics.initialStateArrowLength, height: 6)

            Triangle()
                .fill(Color.green)
                .frame(width: 12, height: 14)
        }
        .shadow(color: Color.green.opacity(0.18), radius: 8, y: 1)
        .accessibilityLabel("Initial state")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct TransitionEdgeView: View {
    @Environment(SwiftMachineStore.self) private var store

    let transition: TransitionDefinition
    let editor: StateMachineEditorSession
    let eventName: String
    let isSelected: Bool

    var body: some View {
        let sourceFrame = editor.document.frame(for: transition.sourceStateID).cgRect
        let targetFrame = editor.document.frame(for: transition.targetStateID).cgRect
        let geometry = TransitionPathGeometry(
            sourceFrame: sourceFrame,
            targetFrame: targetFrame
        )
        let label = transition.graphLabel(eventName: eventName)

        ZStack(alignment: .topLeading) {
            geometry.hitPath
                .fill(Color.black.opacity(0.001))
                .onTapGesture {
                    store.send(.selectTransition(id: transition.id))
                }

            geometry.path
                .stroke(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: isSelected ? 3 : 2,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

            geometry.arrowPath
                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.45))

            Button {
                store.send(.selectTransition(id: transition.id))
            } label: {
                TransitionGraphLabelView(
                    label: label,
                    isSelected: isSelected
                )
            }
            .buttonStyle(.plain)
            .help("Select transition")
            .position(geometry.labelPosition)
        }
    }
}

struct TransitionGraphLabel: Equatable {
    let eventName: String
    let guardName: String?
    let effectNames: [String]
}

extension TransitionDefinition {
    func graphLabel(eventName: String) -> TransitionGraphLabel {
        let trimmedGuardName = self.guard?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGuardName = trimmedGuardName.flatMap { name in
            name.isEmpty ? nil : name
        }
        let normalizedEffectNames = effects.compactMap { effect in
            let trimmedName = effect.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty ? nil : trimmedName
        }

        return TransitionGraphLabel(
            eventName: eventName,
            guardName: normalizedGuardName,
            effectNames: normalizedEffectNames
        )
    }
}

private struct TransitionGraphLabelView: View {
    let label: TransitionGraphLabel
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 10) {
                Text(label.eventName)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)

                if let guardName = label.guardName {
                    HStack {
                        EditorBadge(
                            text: guardName,
                            tint: .green,
                            symbol: "checkmark.shield.fill"
                        )

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, label.effectNames.isEmpty ? 12 : 8)

            if !label.effectNames.isEmpty {
                Rectangle()
                    .fill(Color.primary.opacity(0.18))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(label.effectNames.enumerated()), id: \.offset) { entry in
                        EditorBadge(
                            text: entry.element,
                            tint: .blue,
                            symbol: "sparkles"
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: 240, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.82),
                    lineWidth: isSelected ? 2.5 : 1.5
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 10 : 6, y: 4)
    }
}

private struct ConnectionDraftView: View {
    let sourceAnchor: CGPoint
    let currentLocation: CGPoint
    let isSnapped: Bool

    var body: some View {
        let geometry = ConnectionDraftGeometry(
            start: sourceAnchor,
            end: currentLocation
        )

        ZStack(alignment: .topLeading) {
            geometry.path
                .stroke(
                    Color.accentColor.opacity(0.9),
                    style: StrokeStyle(
                        lineWidth: 2.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [8, 6]
                    )
                )

            geometry.arrowPath
                .fill(Color.accentColor)

            if isSnapped {
                Circle()
                    .stroke(Color.green.opacity(0.9), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .position(currentLocation)
                    .shadow(color: Color.green.opacity(0.28), radius: 8)
            }
        }
    }
}

private struct TransitionPromptView: View {
    @Environment(SwiftMachineStore.self) private var store

    let prompt: StateMachineTransitionPrompt
    let events: [EventDefinition]
    let sourceName: String
    let targetName: String

    @State private var mode: TransitionPromptMode = .createNew
    @State private var selectedEventID = ""
    @State private var newEventName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Create Transition", systemImage: "arrow.triangle.branch")
                .font(.headline)

            Text("\(sourceName) -> \(targetName)")
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
            } else {
                TextField("Event name", text: $newEventName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    store.send(.cancelTransitionPrompt)
                }

                Spacer()

                Button("Create Transition") {
                    if mode == .useExisting {
                        store.send(.confirmTransitionPromptWithExistingEvent(eventID: selectedEventID))
                    } else {
                        store.send(.confirmTransitionPromptWithNewEvent(name: newEventName))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConfirm)
            }
        }
        .padding(18)
        .frame(width: GraphCanvasMetrics.promptWidth, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .onAppear {
            configureDefaults()
        }
    }

    private var canConfirm: Bool {
        if mode == .useExisting {
            return !selectedEventID.isEmpty
        }

        return !newEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

private struct ConnectionSnapTarget: Equatable {
    let stateID: String
    let anchor: StateMachineEditorPoint
}

private struct ConnectionDraftGeometry {
    let path: Path
    let arrowPath: Path

    init(start: CGPoint, end: CGPoint) {
        let horizontalDistance = abs(end.x - start.x)
        let controlOffset = max(70, horizontalDistance * 0.35)
        var control1 = CGPoint(
            x: start.x + controlOffset,
            y: start.y
        )
        var control2 = CGPoint(
            x: end.x - controlOffset,
            y: end.y
        )

        if horizontalDistance < 120 {
            control1.y -= 70
            control2.y -= 70
        }

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        let arrowAngle = atan2(end.y - control2.y, end.x - control2.x)

        self.path = path
        self.arrowPath = TransitionPathGeometry.makeArrowPath(tip: end, angle: arrowAngle)
    }
}

struct TransitionPathGeometry {
    let path: Path
    let hitPath: Path
    let arrowPath: Path
    let arrowTip: CGPoint
    let labelPosition: CGPoint

    init(sourceFrame: CGRect, targetFrame: CGRect) {
        if sourceFrame == targetFrame {
            self = Self.makeSelfLoop(frame: sourceFrame)
        } else {
            self = Self.makeStandardPath(sourceFrame: sourceFrame, targetFrame: targetFrame)
        }
    }

    private init(
        path: Path,
        hitPath: Path,
        arrowPath: Path,
        arrowTip: CGPoint,
        labelPosition: CGPoint
    ) {
        self.path = path
        self.hitPath = hitPath
        self.arrowPath = arrowPath
        self.arrowTip = arrowTip
        self.labelPosition = labelPosition
    }

    private static func makeStandardPath(
        sourceFrame: CGRect,
        targetFrame: CGRect
    ) -> TransitionPathGeometry {
        let isForward = sourceFrame.midX <= targetFrame.midX
        let start = CGPoint(
            x: isForward ? sourceFrame.maxX : sourceFrame.minX,
            y: sourceFrame.midY
        )
        let end = CGPoint(
            x: isForward ? targetFrame.minX : targetFrame.maxX,
            y: targetFrame.midY
        )
        let horizontalDistance = abs(end.x - start.x)
        let controlOffset = max(80, horizontalDistance * 0.35)
        var control1 = CGPoint(
            x: start.x + (isForward ? controlOffset : -controlOffset),
            y: start.y
        )
        var control2 = CGPoint(
            x: end.x - (isForward ? controlOffset : -controlOffset),
            y: end.y
        )

        if horizontalDistance < 120 {
            control1.y -= 90
            control2.y -= 90
        }

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let labelPosition = cubicPoint(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: 0.5
        )
        let arrowAngle = atan2(end.y - control2.y, end.x - control2.x)
        let arrowPath = makeArrowPath(tip: end, angle: arrowAngle)

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: end,
            labelPosition: labelPosition
        )
    }

    private static func makeSelfLoop(frame: CGRect) -> TransitionPathGeometry {
        let start = CGPoint(x: frame.midX + 36, y: frame.minY + 10)
        let end = CGPoint(x: frame.midX - 36, y: frame.minY + 10)
        let control1 = CGPoint(x: frame.maxX + 70, y: frame.minY - 80)
        let control2 = CGPoint(x: frame.minX - 70, y: frame.minY - 80)

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let labelPosition = CGPoint(x: frame.midX, y: frame.minY - 78)
        let arrowPlacement = visibleArrowPlacement(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            avoiding: frame
        )
        let arrowPath = makeArrowPath(tip: arrowPlacement.tip, angle: arrowPlacement.angle)

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: arrowPlacement.tip,
            labelPosition: labelPosition
        )
    }

    private static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let x = (oneMinusT * oneMinusT * oneMinusT * start.x) +
            (3 * oneMinusT * oneMinusT * t * control1.x) +
            (3 * oneMinusT * t * t * control2.x) +
            (t * t * t * end.x)
        let y = (oneMinusT * oneMinusT * oneMinusT * start.y) +
            (3 * oneMinusT * oneMinusT * t * control1.y) +
            (3 * oneMinusT * t * t * control2.y) +
            (t * t * t * end.y)

        return CGPoint(x: x, y: y)
    }

    private static func cubicTangent(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGVector {
        let oneMinusT = 1 - t
        let dx = (3 * oneMinusT * oneMinusT * (control1.x - start.x)) +
            (6 * oneMinusT * t * (control2.x - control1.x)) +
            (3 * t * t * (end.x - control2.x))
        let dy = (3 * oneMinusT * oneMinusT * (control1.y - start.y)) +
            (6 * oneMinusT * t * (control2.y - control1.y)) +
            (3 * t * t * (end.y - control2.y))

        return CGVector(dx: dx, dy: dy)
    }

    private static func visibleArrowPlacement(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        avoiding frame: CGRect
    ) -> (tip: CGPoint, angle: CGFloat) {
        let clearanceFrame = frame.insetBy(dx: -6, dy: -6)
        let tipT = stride(from: 0.99, through: 0.75, by: -0.01)
            .map { CGFloat($0) }
            .first { t in
                let point = cubicPoint(
                    start: start,
                    control1: control1,
                    control2: control2,
                    end: end,
                    t: t
                )
                return !clearanceFrame.contains(point)
            } ?? 1
        let tip = cubicPoint(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: tipT
        )
        let tangent = cubicTangent(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: tipT
        )
        let angle = atan2(tangent.dy, tangent.dx)

        return (tip: tip, angle: angle)
    }

    static func makeArrowPath(tip: CGPoint, angle: CGFloat) -> Path {
        let arrowLength: CGFloat = 12
        let arrowSpread: CGFloat = .pi / 6
        let point1 = CGPoint(
            x: tip.x - cos(angle - arrowSpread) * arrowLength,
            y: tip.y - sin(angle - arrowSpread) * arrowLength
        )
        let point2 = CGPoint(
            x: tip.x - cos(angle + arrowSpread) * arrowLength,
            y: tip.y - sin(angle + arrowSpread) * arrowLength
        )

        return Path { path in
            path.move(to: tip)
            path.addLine(to: point1)
            path.addLine(to: point2)
            path.closeSubpath()
        }
    }
}

private enum GraphCanvasMetrics {
    static let workspaceWidth: CGFloat = 2_400
    static let workspaceHeight: CGFloat = 1_600
    static let defaultZoomScale: CGFloat = 1
    static let minimumZoomScale: CGFloat = 0.5
    static let maximumZoomScale: CGFloat = 2.5
    static let nodeWidth = CGFloat(StateMachineEditorDocument.stateNodeSize.width)
    static let nodeHeight = CGFloat(StateMachineEditorDocument.stateNodeSize.height)
    static let nodePadding: CGFloat = 18
    static let connectionHandleSize: CGFloat = 22
    static let connectionSnapDistance: CGFloat = 44
    static let initialStateArrowLength: CGFloat = 56
    static let promptWidth: CGFloat = 320
    static let promptHeight: CGFloat = 196
    static let edgeHitWidth: CGFloat = 20
}

private extension StateMachineEditorSession {
    func snapTarget(
        for location: StateMachineEditorPoint,
        excluding sourceStateID: String
    ) -> ConnectionSnapTarget? {
        let snapDistance = Double(GraphCanvasMetrics.connectionSnapDistance)

        return document.definition.states
            .filter { $0.id != sourceStateID }
            .map { state in
                let anchor = document.connectionAnchor(for: state.id)
                let distance = hypot(anchor.x - location.x, anchor.y - location.y)
                return (stateID: state.id, anchor: anchor, distance: distance)
            }
            .filter { $0.distance <= snapDistance }
            .min(by: { $0.distance < $1.distance })
            .map { ConnectionSnapTarget(stateID: $0.stateID, anchor: $0.anchor) }
    }
}

private extension StateMachineEditorPoint {
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

private extension StateMachineEditorRect {
    var cgRect: CGRect {
        CGRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}

private extension StateMachineEditorDocument {
    func connectionAnchor(for stateID: String) -> StateMachineEditorPoint {
        let position = position(for: stateID)
        let handleRadius = Double(GraphCanvasMetrics.connectionHandleSize / 2)
        let handlePadding = Double(GraphCanvasMetrics.nodePadding)

        return position.translatingBy(
            dx: Double(GraphCanvasMetrics.nodeWidth) - handlePadding - handleRadius,
            dy: handlePadding + handleRadius
        )
    }
}
