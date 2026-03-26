import SwiftUI

struct TypePaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasEventEffectExecutor
    ) -> TypePaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasEventEffectExecutor
        ) -> TypePaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasEvent: SendEditorCanvasEventEffectExecutor
    ) -> TypePaletteStore {
        makeStore(sendEditorCanvasEvent)
    }
}

extension TypePaletteStoreFactory {
    static let unimplemented = Self { _ in
        missingDependency("typePaletteStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var typePaletteStoreFactory: TypePaletteStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing TypePaletteView dependency: \(label)")
}
