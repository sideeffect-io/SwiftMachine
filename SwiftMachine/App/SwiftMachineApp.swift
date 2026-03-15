//
//  SwiftMachineApp.swift
//  SwiftMachine
//
//  Created by Thibault Wittemberg on 15/03/2026.
//

import SwiftUI

@main
struct SwiftMachineApp: App {
    @State private var stateMachineEditorStore = SwiftMachineStore()

    var body: some Scene {
        WindowGroup {
            SwiftMachineRootView()
                .environment(stateMachineEditorStore)
                .frame(
                    minWidth: SwiftMachineShellMetrics.minimumWindowWidth,
                    minHeight: SwiftMachineShellMetrics.minimumWindowHeight
                )
        }
        .defaultSize(
            width: SwiftMachineShellMetrics.defaultWindowWidth,
            height: SwiftMachineShellMetrics.defaultWindowHeight
        )
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unifiedCompact)
    }
}
