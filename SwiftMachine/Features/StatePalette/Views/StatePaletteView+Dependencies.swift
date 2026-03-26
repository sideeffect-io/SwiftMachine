import SwiftUI

struct StatePaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasEventEffectExecutor
    ) -> StatePaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasEventEffectExecutor
        ) -> StatePaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> StatePaletteStore {
        makeStore(sendEditorCanvasEvent)
    }
}

extension StatePaletteStoreFactory {
    static let unimplemented = Self { _ in
        missingDependency("statePaletteStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var statePaletteStoreFactory: StatePaletteStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing StatePaletteView dependency: \(label)")
}
