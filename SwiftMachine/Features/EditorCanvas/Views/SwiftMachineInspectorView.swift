//
//  SwiftMachineInspectorView.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct SwiftMachineInspectorView: View {
    let store: EditorCanvasStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if store.isEditing {
                    inspectorContent
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Inspector", systemImage: "sidebar.right")
                .font(.title2.weight(.semibold))

            Text("The right panel follows the selected state, event, type, or transition and summarizes the current graph semantics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch store.state.selection {
        case .state(let stateID):
            StateInspectorFeatureView(
                stateID: stateID,
                sendEditorCanvasEvent: store.sendEditorCanvasEvent
            )
            .id("state-inspector-\(stateID)")

        case .event(let eventID):
            EventInspectorFeatureView(
                eventID: eventID,
                sendEditorCanvasEvent: store.sendEditorCanvasEvent
            )
            .id("event-inspector-\(eventID)")

        case .type(let typeID):
            TypeInspectorFeatureView(
                typeID: typeID,
                sendEditorCanvasEvent: store.sendEditorCanvasEvent
            )
            .id("type-inspector-\(typeID)")

        case .transition(let transitionID):
            TransitionInspectorFeatureView(
                transitionID: transitionID,
                sendEditorCanvasEvent: store.sendEditorCanvasEvent
            )
            .id("transition-inspector-\(transitionID)")

        case nil:
            EmptySelectionInspectorView()
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

struct EmptySelectionInspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
            EditorPanelSection(
                title: "How to Use the Graph",
                description: "The shell is diagram-first, so most editing begins on the canvas instead of in a form."
            ) {
                Label("Select a state or event card in the palette to inspect its reusable payload.", systemImage: "sidebar.left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Drag a state card to place it on the graph.", systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Drag from a node handle to another node to create a transition.", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Drag a transition card to rearrange the visual routing of that arrow.", systemImage: "arrow.triangle.branch")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Select an edge to inspect or reassign its event.", systemImage: "slider.horizontal.3")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
