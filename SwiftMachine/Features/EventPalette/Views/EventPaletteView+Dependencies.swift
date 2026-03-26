import SwiftUI

struct EventPaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasCommandEffectExecutor
    ) -> EventPaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasCommandEffectExecutor
        ) -> EventPaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> EventPaletteStore {
        makeStore(sendEditorCanvasCommand)
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
