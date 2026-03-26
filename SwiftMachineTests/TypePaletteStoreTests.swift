//
//  TypePaletteStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 20/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct TypePaletteStoreTests {

    @Test("Adding a struct type emits a selection command for the created type")
    func addStructTypeEmitsSelectionCommand() throws {
        let initialDefinition = try makeTypePaletteDefinition()
        let createdTypeResult = try #require(initialDefinition.addingStructType())
        var canvasCommands: [EditorCanvasCommand] = []

        let store = TypePaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createStructType: .init(
                createStructType: {
                    createdTypeResult.typeID
                }
            ),
            createEnumType: .init(createEnumType: { nil }),
            deleteType: .init(deleteType: { _ in nil }),
            sendEditorCanvasCommand: .init(send: { canvasCommands.append($0) })
        )

        store.send(.addStructTypeTapped)

        #expect(
            canvasCommands == [
                .selectWhenAvailable(.type(id: createdTypeResult.typeID))
            ]
        )
    }

    @Test("A snapshot update refreshes the local type definition snapshot")
    func snapshotUpdateRefreshesDefinition() throws {
        let definition = try makeTypePaletteDefinition()
        let updatedDefinition = try #require(definition.addingEnumType()?.definition)

        let store = TypePaletteStore(
            observeDefinition: .init(
                observeDefinition: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            ),
            createStructType: .init(createStructType: { nil }),
            createEnumType: .init(createEnumType: { nil }),
            deleteType: .init(deleteType: { _ in nil }),
            sendEditorCanvasCommand: .init(send: { _ in })
        )

        store.send(
            .snapshotDidChange(
                CurrentStateMachineDefinitionSnapshot(
                    definition: updatedDefinition,
                    revision: 2
                )
            )
        )

        #expect(store.state.snapshot.definition == updatedDefinition)
        #expect(store.types.count == 1)
    }
}

private func makeTypePaletteDefinition() throws -> StateMachineDefinition {
    try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
}
