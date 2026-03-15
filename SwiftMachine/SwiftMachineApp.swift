//
//  SwiftMachineApp.swift
//  SwiftMachine
//
//  Created by Thibault Wittemberg on 15/03/2026.
//

import SwiftUI

@main
struct SwiftMachineApp: App {
    var body: some Scene {
        WindowGroup {
            StateMachineEditorView()
                .frame(
                    minWidth: EditorShellMetrics.minimumWindowWidth,
                    minHeight: EditorShellMetrics.minimumWindowHeight
                )
        }
        .defaultSize(
            width: EditorShellMetrics.defaultWindowWidth,
            height: EditorShellMetrics.defaultWindowHeight
        )
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
    }
}
