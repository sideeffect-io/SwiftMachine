//
//  CurrentStateMachineDefinitionServiceTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

struct CurrentStateMachineDefinitionServiceTests {

    @Test("The shared definition service starts empty")
    func startsEmpty() {
        let service = CurrentStateMachineDefinitionService()

        #expect(service.snapshot() == .empty)
    }

    @Test("Replace, update, and clear mutate the snapshot and increment the revision")
    func replaceUpdateAndClear() throws {
        let service = CurrentStateMachineDefinitionService()
        let initialDefinition = try makeDefinition()

        let replaced = service.replace(with: initialDefinition)
        #expect(replaced.definition?.name == "Checkout")
        #expect(replaced.revision == 1)

        let updated = try #require(
            service.update { definition in
                definition.renamingState(id: definition.initialStateID, to: "Ready")
            }
        )
        #expect(updated.definition?.states.first?.name == "Ready")
        #expect(updated.revision == 2)

        let cleared = service.clear()
        #expect(cleared.definition == nil)
        #expect(cleared.revision == 3)
    }

    @Test("Observers receive the initial snapshot and subsequent mutations")
    func observersReceiveSnapshots() async throws {
        let service = CurrentStateMachineDefinitionService()
        let definition = try makeDefinition()

        let collectedTask = Task { () -> [CurrentStateMachineDefinitionSnapshot] in
            var iterator = service.observe().makeAsyncIterator()
            var snapshots: [CurrentStateMachineDefinitionSnapshot] = []

            while snapshots.count < 3, let snapshot = await iterator.next() {
                snapshots.append(snapshot)
            }

            return snapshots
        }

        await Task.yield()
        _ = service.replace(with: definition)
        _ = service.clear()

        let snapshots = await collectedTask.value

        #expect(snapshots == [
            .empty,
            CurrentStateMachineDefinitionSnapshot(definition: definition, revision: 1),
            CurrentStateMachineDefinitionSnapshot(definition: nil, revision: 2)
        ])
    }
}

private func makeDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
