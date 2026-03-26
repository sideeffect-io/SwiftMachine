import SwiftUI

struct EventPaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasEventEffectExecutor
    ) -> EventPaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasEventEffectExecutor
        ) -> EventPaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> EventPaletteStore {
        makeStore(sendEditorCanvasEvent)
    }
}

extension EventPaletteStoreFactory {
    static let unimplemented = Self { _ in
        missingDependency("eventPaletteStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var eventPaletteStoreFactory: EventPaletteStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing EventPaletteView dependency: \(label)")
}
