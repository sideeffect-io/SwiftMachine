import SwiftUI

struct TypeInspectorStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable (
        String,
        SendEditorCanvasCommandEffectExecutor
    ) -> TypeInspectorStore

    init(
        make: @escaping @MainActor @Sendable (
            String,
            SendEditorCanvasCommandEffectExecutor
        ) -> TypeInspectorStore
    ) {
        self.makeStore = make
    }

    @MainActor
    func make(
        typeID: String,
        sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor
    ) -> TypeInspectorStore {
        makeStore(typeID, sendEditorCanvasCommand)
    }
}

extension TypeInspectorStoreFactory {
    static let unimplemented = Self { _, _ in
        missingDependency("typeInspectorStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var typeInspectorStoreFactory: TypeInspectorStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing TypeInspectorView dependency: \(label)")
}
