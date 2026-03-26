//
//  SwiftMachineApp.swift
//  SwiftMachine
//
//  Created by Thibault Wittemberg on 15/03/2026.
//

import SwiftUI

@main
struct SwiftMachineApp: App {
    private let compositionRoot = AppCompositionRoot()

    var body: some Scene {
        WindowGroup {
            SwiftMachineRootView()
                .appCompositionRoot(compositionRoot)
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
