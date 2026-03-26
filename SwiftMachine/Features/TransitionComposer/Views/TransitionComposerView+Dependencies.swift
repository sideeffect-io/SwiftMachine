import SwiftUI

struct TransitionComposerStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        StateMachineTransitionPrompt,
        SendEditorCanvasEventEffectExecutor
    ) -> TransitionComposerStore

    init(
        make: @escaping @MainActor @Sendable (
            StateMachineTransitionPrompt,
            SendEditorCanvasEventEffectExecutor
        ) -> TransitionComposerStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        prompt: StateMachineTransitionPrompt,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> TransitionComposerStore {
        makeStore(prompt, sendEditorCanvasEvent)
    }
}

extension TransitionComposerStoreFactory {
    static let unimplemented = Self { _, _ in
        missingDependency("transitionComposerStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var transitionComposerStoreFactory: TransitionComposerStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing TransitionComposerView dependency: \(label)")
}
