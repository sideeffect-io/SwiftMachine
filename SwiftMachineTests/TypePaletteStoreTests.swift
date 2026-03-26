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

    @Test("Adding a struct type routes the mutation to the root canvas and selects the created type")
    func addStructTypeRoutesDefinitionMutation() throws {
        let initialDefinition = try makeTypePaletteDefinition()
        let createdTypeResult = try #require(initialDefinition.addingStructType())
        var canvasEvents: [EditorCanvasStore.Event] = []

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
                    DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: createdTypeResult.definition,
                            revision: 2
                        ),
                        preferredSelection: .type(id: createdTypeResult.typeID)
                    )
                }
            ),
            createEnumType: .init(createEnumType: { nil }),
            deleteType: .init(deleteType: { _ in nil }),
            sendEditorCanvasEvent: .init(send: { canvasEvents.append($0) })
        )

        store.send(.addStructTypeTapped)

        #expect(
            canvasEvents == [
                .definitionMutationWasApplied(
                    DefinitionMutationResult(
                        snapshot: CurrentStateMachineDefinitionSnapshot(
                            definition: createdTypeResult.definition,
                            revision: 2
                        ),
                        preferredSelection: .type(id: createdTypeResult.typeID)
                    ),
                    transitionPositionOverride: nil
                )
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
            sendEditorCanvasEvent: .init(send: { _ in })
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
