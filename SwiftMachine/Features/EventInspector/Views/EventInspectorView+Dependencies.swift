import SwiftUI

struct EventInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasCommandEffectExecutor
    ) -> EventInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasCommandEffectExecutor
        ) -> EventInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        eventID: String,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> EventInspectorStore {
        makeStore(eventID, sendEditorCanvasCommand)
    }
}

extension EventInspectorStoreFactory {
    static let unimplemented = Self { _, _ in
        missingDependency("eventInspectorStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var eventInspectorStoreFactory: EventInspectorStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing EventInspectorView dependency: \(label)")
}
