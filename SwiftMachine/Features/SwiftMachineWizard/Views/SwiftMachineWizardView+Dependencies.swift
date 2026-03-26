import SwiftUI

struct SwiftMachineWizardStoreFactory: Sendable {
    private let makeStore: @MainActor @Sendable () -> SwiftMachineWizardStore

    init(make: @escaping @MainActor @Sendable () -> SwiftMachineWizardStore) {
        self.makeStore = make
    }

    @MainActor
    func make() -> SwiftMachineWizardStore {
        makeStore()
    }
}

extension SwiftMachineWizardStoreFactory {
    static let unimplemented = Self {
        missingDependency("swiftMachineWizardStoreFactory")
    }
}

extension EnvironmentValues {
    @Entry var swiftMachineWizardStoreFactory: SwiftMachineWizardStoreFactory = .unimplemented
}

private func missingDependency(_ label: StaticString) -> Never {
    fatalError("Missing SwiftMachineWizardView dependency: \(label)")
}
