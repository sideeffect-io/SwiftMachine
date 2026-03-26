//
//  SwiftMachineCanvasView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineCanvasView: View {
    @Environment(\.editorCanvasStoreFactory) private var editorCanvasStoreFactory

    var body: some View {
        WithViewStore(store: editorCanvasStoreFactory.make()) { store in
            content(for: store)
        }
    }

    @ViewBuilder
    private func content(for store: EditorCanvasStore) -> some View {
        Group {
            switch store.state.phase {
            case .wizard:
                SwiftMachineWizardView()

            case .editing:
                if let editor = store.presentationState {
                    editingSurface(editor: editor, store: store)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func editingSurface(
        editor: EditorCanvasPresentationState,
        store: EditorCanvasStore
    ) -> some View {
        HSplitView {
            SwiftMachineToolboxView(store: store)
                .frame(
                    minWidth: SwiftMachineShellMetrics.sidebarMinimumWidth,
                    idealWidth: SwiftMachineShellMetrics.sidebarIdealWidth,
                    maxWidth: SwiftMachineShellMetrics.sidebarMaximumWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )

            SwiftMachineGraphCanvasView(store: store, editor: editor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SwiftMachineInspectorView(store: store)
                .frame(
                    minWidth: SwiftMachineShellMetrics.inspectorMinimumWidth,
                    idealWidth: SwiftMachineShellMetrics.inspectorIdealWidth,
                    maxWidth: SwiftMachineShellMetrics.inspectorMaximumWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
    }
}

#Preview {
    SwiftMachineRootView()
        .appCompositionRoot(.init())
        .frame(width: 900, height: 700)
}
