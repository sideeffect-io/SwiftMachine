//
//  StateMachineEditorView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct StateMachineEditorView: View {
    var body: some View {
        HSplitView {
            ToolboxSidebarView()
                .frame(
                    minWidth: EditorShellMetrics.sidebarMinimumWidth,
                    idealWidth: EditorShellMetrics.sidebarIdealWidth,
                    maxWidth: EditorShellMetrics.sidebarMaximumWidth
                )

            StateMachineCanvasPlaceholderView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    StateMachineEditorView()
        .frame(
            width: EditorShellMetrics.defaultWindowWidth,
            height: EditorShellMetrics.defaultWindowHeight
        )
}
