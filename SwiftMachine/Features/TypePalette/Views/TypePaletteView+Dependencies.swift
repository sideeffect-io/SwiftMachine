import SwiftUI

struct TypePaletteStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        SendEditorCanvasCommandEffectExecutor
    ) -> TypePaletteStore

    init(
        make: @escaping @MainActor @Sendable (
            SendEditorCanvasCommandEffectExecutor
        ) -> TypePaletteStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> TypePaletteStore {
        makeStore(sendEditorCanvasCommand)
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
