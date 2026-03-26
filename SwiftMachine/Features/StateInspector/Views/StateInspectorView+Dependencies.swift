import SwiftUI

struct StateInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasEventEffectExecutor
    ) -> StateInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasEventEffectExecutor
        ) -> StateInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        stateID: String,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> StateInspectorStore {
        makeStore(stateID, sendEditorCanvasEvent)
    }
}

extension StateInspectorStoreFactory {
    static let unimplemented = Self { _, _ in
        missingDependency("stateInspectorStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var stateInspectorStoreFactory: StateInspectorStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing StateInspectorView dependency: \(label)")
}
