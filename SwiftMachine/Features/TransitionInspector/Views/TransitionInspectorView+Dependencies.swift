import SwiftUI

struct TransitionInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasCommandEffectExecutor
    ) -> TransitionInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasCommandEffectExecutor
        ) -> TransitionInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        transitionID: String,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> TransitionInspectorStore {
        makeStore(transitionID, sendEditorCanvasCommand)
    }
}

extension TransitionInspectorStoreFactory {
    static let unimplemented = Self { _, _ in
        missingDependency("transitionInspectorStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var transitionInspectorStoreFactory: TransitionInspectorStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing TransitionInspectorView dependency: \(label)")
}
