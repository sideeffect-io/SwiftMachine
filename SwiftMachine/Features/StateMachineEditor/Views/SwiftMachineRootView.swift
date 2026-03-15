//
//  SwiftMachineRootView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineRootView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        Group {
            if store.state.isDesigning {
                HSplitView {
                    SwiftMachineToolboxView()
                        .frame(
                            minWidth: SwiftMachineShellMetrics.sidebarMinimumWidth,
                            idealWidth: SwiftMachineShellMetrics.sidebarIdealWidth,
                            maxWidth: SwiftMachineShellMetrics.sidebarMaximumWidth
                        )

                    SwiftMachineCanvasView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                SwiftMachineCanvasView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    SwiftMachineRootView()
        .environment(SwiftMachineStore())
        .frame(
            width: SwiftMachineShellMetrics.defaultWindowWidth,
            height: SwiftMachineShellMetrics.defaultWindowHeight
        )
}

#Preview("Designing") {
    SwiftMachineRootView()
        .environment(
            SwiftMachineStore.make(
                initialState: .designing(
                    stateMachine: .makeNew(
                        name: "Checkout",
                        initialStateName: "Idle",
                        initialStateProperties: []
                    )!
                )
            )
        )
        .frame(
            width: SwiftMachineShellMetrics.defaultWindowWidth,
            height: SwiftMachineShellMetrics.defaultWindowHeight
        )
}
