//
//  SwiftMachineToolboxView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineToolboxView: View {
    let store: EditorCanvasStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if editor != nil {
                    StatePaletteView(
                        selectedStateID: store.selectedStateID,
                        sendEditorCanvasEvent: store.sendEditorCanvasEvent
                    )
                    EventPaletteView(
                        selectedEventID: store.selectedEventID,
                        sendEditorCanvasEvent: store.sendEditorCanvasEvent
                    )
                    TypePaletteView(
                        selectedTypeID: store.selectedTypeID,
                        sendEditorCanvasEvent: store.sendEditorCanvasEvent
                    )
                } else {
                    EditorPanelSection(
                        title: "Wizard",
                        description: "The toolbox activates after the machine name and initial state have been provided."
                    ) {
                        EditorInfoRow(label: "Status", value: "Waiting for setup", symbol: "square.and.pencil")
                    }
                }

                footerNote
            }
            .padding(SwiftMachineShellMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var editor: EditorCanvasPresentationState? {
        store.presentationState
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Palette", systemImage: "shippingbox")
                .font(.title2.weight(.semibold))

            Text("The left panel owns machine-wide creation actions plus the reusable state, event, and type libraries for the graph.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerNote: some View {
        Label("Transitions are authored directly on the canvas by dragging from one state node to another.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    SwiftMachineRootView()
        .appCompositionRoot(.init())
        .frame(width: SwiftMachineShellMetrics.sidebarIdealWidth, height: 700)
}
