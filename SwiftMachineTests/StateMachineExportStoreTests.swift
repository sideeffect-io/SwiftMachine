//
//  StateMachineExportStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Foundation
import Testing
@testable import SwiftMachine

@MainActor
struct StateMachineExportStoreTests {

    @Test("Starting the export store enables definition observation")
    func startEnablesObservation() {
        let store = makeStore(saveResult: .cancelled)

        store.start()

        #expect(store.state.isObservingDefinition)
    }

    @Test("Snapshot updates render the current export and preview toggles from user actions")
    func snapshotUpdateRendersExportAndPreviewFlow() throws {
        let definition = try makeStoreDefinition()
        let store = makeStore(saveResult: .cancelled)

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: definition,
                    revision: 3
                )
            )
        )

        let renderedExport = try #require(store.state.renderedExport)
        #expect(renderedExport.machineName == "Checkout")
        #expect(renderedExport.revision == 3)

        store.send(.exportTapped)
        #expect(store.state.isPreviewPresented)

        store.send(.dismissPreview)
        #expect(!store.state.isPreviewPresented)
    }

    @Test("Saving dispatches the rendered export and closes the preview on success")
    func saveDispatchClosesPreviewOnSuccess() throws {
        let definition = try makeStoreDefinition()
        let expectedURL = URL(fileURLWithPath: "/tmp/Checkout.state-machine.md")
        var capturedExport: RenderedStateMachineExport?
        let store = makeStore(
            saveResult: .saved(expectedURL),
            onSave: { capturedExport = $0 }
        )

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: definition,
                    revision: 5
                )
            )
        )
        store.send(.exportTapped)
        store.send(.saveTapped)

        let renderedExport = try #require(capturedExport)
        #expect(renderedExport.revision == 5)
        #expect(!store.state.isPreviewPresented)
        #expect(store.state.lastSavedFileURL == expectedURL)
        #expect(store.state.previewErrorMessage == nil)
    }

    @Test("Save failures keep the preview open and expose the error message")
    func saveFailureKeepsPreviewOpen() throws {
        let definition = try makeStoreDefinition()
        let store = makeStore(saveResult: .failed("Disk full"))

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: definition,
                    revision: 2
                )
            )
        )
        store.send(.exportTapped)
        store.send(.saveTapped)

        #expect(store.state.isPreviewPresented)
        #expect(store.state.previewErrorMessage == "Disk full")
        #expect(store.state.lastSavedFileURL == nil)
    }

    @Test("Cancelling the save panel keeps the preview open without recording an error")
    func cancelledSaveKeepsPreviewOpenWithoutError() throws {
        let definition = try makeStoreDefinition()
        let store = makeStore(saveResult: .cancelled)

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: definition,
                    revision: 2
                )
            )
        )
        store.send(.exportTapped)
        store.send(.saveTapped)

        #expect(store.state.isPreviewPresented)
        #expect(store.state.previewErrorMessage == nil)
        #expect(store.state.lastSavedFileURL == nil)
    }
}

@MainActor
private func makeStore(
    saveResult: StateMachineExportSaveResult,
    onSave: @escaping (RenderedStateMachineExport) -> Void = { _ in }
) -> StateMachineExportStore {
    StateMachineExportStore(
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        saveRenderedExport: .init(
            save: { renderedExport in
                onSave(renderedExport)
                return saveResult
            }
        )
    )
}

private func makeStoreDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
