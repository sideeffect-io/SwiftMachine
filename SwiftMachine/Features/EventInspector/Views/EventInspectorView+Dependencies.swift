import SwiftUI

struct EventInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasEventEffectExecutor
    ) -> EventInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasEventEffectExecutor
        ) -> EventInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        eventID: String,
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> EventInspectorStore {
        makeStore(eventID, sendEditorCanvasEvent)
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
