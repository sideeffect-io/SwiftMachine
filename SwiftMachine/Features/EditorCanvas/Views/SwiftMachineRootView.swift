//
//  SwiftMachineRootView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct SwiftMachineRootView: View {
    var body: some View {
        SwiftMachineCanvasView()
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    SwiftMachineRootView()
        .appCompositionRoot(.init())
        .frame(
            width: SwiftMachineShellMetrics.defaultWindowWidth,
            height: SwiftMachineShellMetrics.defaultWindowHeight
        )
}
