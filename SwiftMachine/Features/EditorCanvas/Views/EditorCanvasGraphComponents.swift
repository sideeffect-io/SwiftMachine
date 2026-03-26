//
//  EditorCanvasGraphComponents.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import SwiftUI

struct GraphCanvasBackground: View {
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

struct StateNodeView: View {
    let store: EditorCanvasStore
    let state: StateDefinition
    let editor: EditorCanvasPresentationState
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
                    isSelected ? Color.orange : Color.orange.opacity(0.88),
                    lineWidth: isSelected ? 4.5 : 3.25
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

struct TransitionCardView: View {
    let store: EditorCanvasStore
    let transition: TransitionDefinition
    let label: TransitionGraphLabel
    let position: StateMachineEditorPoint
    let isSelected: Bool
    let canvasScale: CGFloat

    @State private var dragOrigin: StateMachineEditorPoint?

    var body: some View {
        TransitionGraphLabelView(
            label: label,
            isSelected: isSelected
        )
        .position(position.cgPoint)
        .help("Drag to rearrange the transition path.")
        .onTapGesture {
            store.send(.selectTransition(id: transition.id))
        }
        .simultaneousGesture(cardDragGesture)
    }

    private var cardDragGesture: some Gesture {
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

                store.send(.moveTransition(id: transition.id, to: clamp(nextPosition)))
            }
            .onEnded { _ in
                dragOrigin = nil
            }
    }

    private func clamp(_ point: StateMachineEditorPoint) -> StateMachineEditorPoint {
        let halfWidth = GraphCanvasMetrics.transitionCardWidth / 2
        let halfHeight = GraphCanvasMetrics.transitionCardHeight / 2

        return StateMachineEditorPoint(
            x: min(max(point.x, Double(halfWidth)), Double(GraphCanvasMetrics.workspaceWidth - halfWidth)),
            y: min(max(point.y, Double(halfHeight)), Double(GraphCanvasMetrics.workspaceHeight - halfHeight))
        )
    }

    private func normalizedTranslation(for translation: CGSize) -> CGSize {
        let safeScale = max(canvasScale, .leastNonzeroMagnitude)
        return CGSize(
            width: translation.width / safeScale,
            height: translation.height / safeScale
        )
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

struct TransitionEdgeView: View {
    let store: EditorCanvasStore
    let transition: TransitionDefinition
    let editor: EditorCanvasPresentationState
    let position: StateMachineEditorPoint
    let isSelected: Bool

    var body: some View {
        let sourceFrame = editor.document.frame(for: transition.sourceStateID).cgRect
        let targetFrame = editor.document.frame(for: transition.targetStateID).cgRect
        let geometry = TransitionPathGeometry(
            sourceFrame: sourceFrame,
            transitionAnchor: position.cgPoint,
            targetFrame: targetFrame
        )

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
        .frame(width: GraphCanvasMetrics.transitionCardWidth, alignment: .leading)
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

struct ConnectionDraftView: View {
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
