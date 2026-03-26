//
//  CurrentStateMachineDefinitionService.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation
import Synchronization

struct CurrentStateMachineDefinitionSnapshot: Sendable, Equatable {
    let definition: StateMachineDefinition?
    let revision: UInt64

    static let empty = CurrentStateMachineDefinitionSnapshot(definition: nil, revision: 0)
}

final class CurrentStateMachineDefinitionService: Sendable {
    private final class StorageBox: Sendable {
        let mutex: Mutex<Storage>

        init(_ storage: Storage) {
            mutex = Mutex(storage)
        }
    }

    private struct Storage {
        var snapshot: CurrentStateMachineDefinitionSnapshot
        var observers: [UUID: AsyncStream<CurrentStateMachineDefinitionSnapshot>.Continuation]
    }

    private let storage: StorageBox

    init(
        initialSnapshot: CurrentStateMachineDefinitionSnapshot = .empty
    ) {
        storage = StorageBox(
            Storage(
                snapshot: initialSnapshot,
                observers: [:]
            )
        )
    }

    nonisolated func snapshot() -> CurrentStateMachineDefinitionSnapshot {
        storage.mutex.withLock { $0.snapshot }
    }

    @discardableResult
    nonisolated func replace(with definition: StateMachineDefinition) -> CurrentStateMachineDefinitionSnapshot {
        guard let snapshot = applyMutation({ storage in
            let snapshot = CurrentStateMachineDefinitionSnapshot(
                definition: definition,
                revision: storage.snapshot.revision + 1
            )
            storage.snapshot = snapshot
            return snapshot
        }) else {
            preconditionFailure("Replacing the current definition must always produce a snapshot.")
        }

        return snapshot
    }

    @discardableResult
    nonisolated func update(
        _ mutate: (StateMachineDefinition) -> StateMachineDefinition?
    ) -> CurrentStateMachineDefinitionSnapshot? {
        applyMutation { storage in
            guard let currentDefinition = storage.snapshot.definition,
                  let updatedDefinition = mutate(currentDefinition) else {
                return nil
            }

            let snapshot = CurrentStateMachineDefinitionSnapshot(
                definition: updatedDefinition,
                revision: storage.snapshot.revision + 1
            )
            storage.snapshot = snapshot
            return snapshot
        }
    }

    @discardableResult
    nonisolated func clear() -> CurrentStateMachineDefinitionSnapshot {
        guard let snapshot = applyMutation({ storage in
            let snapshot = CurrentStateMachineDefinitionSnapshot(
                definition: nil,
                revision: storage.snapshot.revision + 1
            )
            storage.snapshot = snapshot
            return snapshot
        }) else {
            preconditionFailure("Clearing the current definition must always produce a snapshot.")
        }

        return snapshot
    }

    nonisolated func observe() -> AsyncStream<CurrentStateMachineDefinitionSnapshot> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let registration = self.storage.mutex.withLock { storage in
                let observerID = UUID()
                storage.observers[observerID] = continuation
                return (observerID, storage.snapshot)
            }

            continuation.yield(registration.1)

            continuation.onTermination = { [weak self] _ in
                self?.storage.mutex.withLock { storage in
                    _ = storage.observers.removeValue(forKey: registration.0)
                }
            }
        }
    }

    nonisolated private func applyMutation(
        _ mutate: (inout Storage) -> CurrentStateMachineDefinitionSnapshot?
    ) -> CurrentStateMachineDefinitionSnapshot? {
        let payload = storage.mutex.withLock { storage -> (CurrentStateMachineDefinitionSnapshot, [AsyncStream<CurrentStateMachineDefinitionSnapshot>.Continuation])? in
            guard let snapshot = mutate(&storage) else {
                return nil
            }

            return (snapshot, Array(storage.observers.values))
        }

        guard let payload else {
            return nil
        }

        for observer in payload.1 {
            observer.yield(payload.0)
        }

        return payload.0
    }
}
