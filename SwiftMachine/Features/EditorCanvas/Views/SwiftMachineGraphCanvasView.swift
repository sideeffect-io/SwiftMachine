//
//  SwiftMachineGraphCanvasView.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct SwiftMachineGraphCanvasView: View {
    let store: EditorCanvasStore
    let editor: EditorCanvasPresentationState

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
        editor.definition
    }

    private var selectedStateID: String? {
        guard case .state(let stateID) = editor.selection else {
            return nil
        }

        return stateID
    }

    private var selectedEventID: String? {
        guard case .event(let eventID) = editor.selection else {
            return nil
        }

        return eventID
    }

    private var selectedTransitionID: String? {
        guard case .transition(let transitionID) = editor.selection else {
            return nil
        }

        return transitionID
    }

    private var highlightedTransitionIDs: Set<String> {
        if let selectedTransitionID {
            return [selectedTransitionID]
        }

        guard let selectedEventID else {
            return []
        }

        return Set(
            definition.transitions
                .filter { $0.eventID == selectedEventID }
                .map(\.id)
        )
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

                Text("Drag states to position them, or drag transition cards to rearrange the arrow routing. Drag from a node handle to create a transition. Pinch to zoom the canvas.")
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
                let label = transition.graphLabel(eventName: eventName(for: transition.eventID))
                let transitionPosition = transitionPosition(for: transition)
                let isHighlighted = highlightedTransitionIDs.contains(transition.id)

                TransitionEdgeView(
                    store: store,
                    transition: transition,
                    editor: editor,
                    position: transitionPosition,
                    isSelected: isHighlighted
                )
                .zIndex(0)

                TransitionCardView(
                    store: store,
                    transition: transition,
                    label: label,
                    position: transitionPosition,
                    isSelected: isHighlighted,
                    canvasScale: canvasScale
                )
                .zIndex(1)
            }

            ForEach(definition.states) { state in
                StateNodeView(
                    store: store,
                    state: state,
                    editor: editor,
                    position: editor.document.position(for: state.id),
                    isInitial: state.id == definition.initialStateID,
                    isSelected: selectedStateID == state.id,
                    isConnectionSnapTarget: currentConnectionSnapTarget?.stateID == state.id,
                    canvasScale: canvasScale
                )
                .zIndex(2)
            }

            if let connectionDraft = editor.connectionDraft {
                ConnectionDraftView(
                    sourceAnchor: editor.document.connectionAnchor(for: connectionDraft.sourceStateID).cgPoint,
                    currentLocation: connectionDraft.currentLocation.cgPoint,
                    isSnapped: currentConnectionSnapTarget != nil
                )
                .zIndex(3)
            }

            if let prompt = editor.transitionPrompt {
                TransitionComposerView(
                    prompt: prompt,
                    events: definition.events,
                    sourceState: definition.states.first(where: { $0.id == prompt.sourceStateID }),
                    targetState: definition.states.first(where: { $0.id == prompt.targetStateID }),
                    availableModelTypes: definition.types,
                    sendEditorCanvasCommand: store.sendEditorCanvasCommand
                )
                .id(promptIdentity(prompt))
                .position(promptPosition(for: prompt.anchor))
                .zIndex(4)
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

    private func eventName(for eventID: String) -> String {
        definition.events.first(where: { $0.id == eventID })?.name ?? eventID
    }

    private func transitionPosition(for transition: TransitionDefinition) -> StateMachineEditorPoint {
        if let storedPosition = editor.document.transitionPosition(for: transition.id) {
            return storedPosition
        }

        let sourceFrame = editor.document.frame(for: transition.sourceStateID).cgRect
        let targetFrame = editor.document.frame(for: transition.targetStateID).cgRect
        let fallbackGeometry = TransitionPathGeometry(
            sourceFrame: sourceFrame,
            targetFrame: targetFrame
        )

        return StateMachineEditorPoint(
            x: fallbackGeometry.labelPosition.x,
            y: fallbackGeometry.labelPosition.y
        )
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
