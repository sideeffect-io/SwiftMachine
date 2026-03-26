//
//  TypeInspectorStoreTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 26/03/2026.
//

import Testing
@testable import SwiftMachine

@MainActor
struct TypeInspectorStoreTests {

    @Test("Updating a type name delegates the mutation without emitting presentation commands")
    func updateTypeNameDoesNotEmitPresentationCommands() throws {
        let fixture = try makeTypeInspectorFixture()
        let updatedDefinition = try #require(
            fixture.definition.renamingType(id: fixture.typeID, to: "User")
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 2
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTypeInspectorStore(
            typeID: fixture.typeID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateTypeName: { receivedTypeID, name in
                #expect(receivedTypeID == fixture.typeID)
                #expect(name == "User")
                return snapshot
            }
        )

        store.send(.updateTypeName("User"))

        #expect(canvasCommands.isEmpty)
    }

    @Test("Updating a type definition delegates the mutation without emitting presentation commands")
    func updateTypeDoesNotEmitPresentationCommands() throws {
        let fixture = try makeTypeInspectorFixture()
        let updatedType = PayloadTypeDefinition(
            id: fixture.typeID,
            name: "Profile",
            kind: .structType(fields: [
                PropertyDefinition(name: "id", type: .integer)
            ])
        )
        let updatedDefinition = try #require(
            fixture.definition.updatingType(updatedType, forTypeID: fixture.typeID)
        )
        let snapshot = CurrentStateMachineDefinitionSnapshot(
            definition: updatedDefinition,
            revision: 3
        )
        var canvasCommands: [EditorCanvasCommand] = []

        let store = makeTypeInspectorStore(
            typeID: fixture.typeID,
            sendEditorCanvasCommand: { canvasCommands.append($0) },
            updateType: { receivedTypeID, receivedType in
                #expect(receivedTypeID == fixture.typeID)
                #expect(receivedType == updatedType)
                return snapshot
            }
        )

        store.send(.updateType(updatedType))

        #expect(canvasCommands.isEmpty)
    }
}

@MainActor
private func makeTypeInspectorStore(
    typeID: String,
    sendEditorCanvasCommand: @escaping @MainActor @Sendable (EditorCanvasCommand) -> Void = { _ in },
    updateTypeName: @escaping @Sendable (String, String) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil },
    updateType: @escaping @Sendable (String, PayloadTypeDefinition) -> CurrentStateMachineDefinitionSnapshot? = { _, _ in nil }
) -> TypeInspectorStore {
    TypeInspectorStore(
        typeID: typeID,
        observeDefinition: .init(
            observeDefinition: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        ),
        updateTypeName: .init(updateTypeName: updateTypeName),
        updateType: .init(updateType: updateType),
        sendEditorCanvasCommand: .init(send: sendEditorCanvasCommand)
    )
}

private struct TypeInspectorFixture {
    let definition: StateMachineDefinition
    let typeID: String
}

private func makeTypeInspectorFixture() throws -> TypeInspectorFixture {
    let definition = try #require(
        StateMachineDefinition.makeNew(
            name: "Checkout",
            initialStateName: "Idle",
            initialStateProperties: []
        )
    )
    let addedType = try #require(definition.addingStructType())

    return TypeInspectorFixture(
        definition: addedType.definition,
        typeID: addedType.typeID
    )
}
