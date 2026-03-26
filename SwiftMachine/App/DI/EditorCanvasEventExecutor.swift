//
//  EditorCanvasEventExecutor.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

struct SendEditorCanvasEventEffectExecutor: Sendable {
    let send: @MainActor @Sendable (EditorCanvasStore.Event) -> Void

    @MainActor
    func callAsFunction(_ event: EditorCanvasStore.Event) {
        send(event)
    }
}

extension EditorCanvasStore {
    @MainActor
    var sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor {
        SendEditorCanvasEventEffectExecutor(
            send: { event in
                self.send(event)
            }
        )
    }
}
