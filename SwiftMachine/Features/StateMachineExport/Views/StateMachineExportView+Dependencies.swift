import SwiftUI

struct StateMachineExportStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable () -> StateMachineExportStore

    init(make: @escaping @MainActor @Sendable () -> StateMachineExportStore) {
        self.makeStore = make
    }

    @MainActor
    func make() -> StateMachineExportStore {
        makeStore()
    }
}

extension StateMachineExportStoreFactory {
    static let unimplemented = Self {
        missingDependency("stateMachineExportStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var stateMachineExportStoreFactory: StateMachineExportStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing StateMachineExportView dependency: \(label)")
}
