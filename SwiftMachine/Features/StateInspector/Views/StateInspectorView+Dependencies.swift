import SwiftUI

struct StateInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasCommandEffectExecutor
    ) -> StateInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasCommandEffectExecutor
        ) -> StateInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        stateID: String,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> StateInspectorStore {
        makeStore(stateID, sendEditorCanvasCommand)
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
