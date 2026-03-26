import SwiftUI

struct StatePaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasCommandEffectExecutor
    ) -> StatePaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasCommandEffectExecutor
        ) -> StatePaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> StatePaletteStore {
        makeStore(sendEditorCanvasCommand)
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
