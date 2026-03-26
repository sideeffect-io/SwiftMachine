import SwiftUI

struct EditorCanvasStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable () -> EditorCanvasStore

    init(make: @escaping @MainActor @Sendable () -> EditorCanvasStore) {
        self.makeStore = make
    }

    @MainActor
    func make() -> EditorCanvasStore {
        makeStore()
    }
}

extension EditorCanvasStoreFactory {
    static let unimplemented = Self {
        missingDependency("editorCanvasStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var editorCanvasStoreFactory: EditorCanvasStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing SwiftMachineCanvasView dependency: \(label)")
}
