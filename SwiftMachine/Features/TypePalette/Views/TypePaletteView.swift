//
//  TypePaletteView.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct TypePaletteView: View {
    @Environment(\.typePaletteStoreFactory) private var typePaletteStoreFactory

    let selectedTypeID: String?
    let sendEditorCanvasCommand: SendEditorCanvasCommandEffectExecutor

    var body: some View {
        WithViewStore(
            store: typePaletteStoreFactory.make(
                sendEditorCanvasCommand: sendEditorCanvasCommand
            )
        ) { store in
            content(for: store)
        }
    }

    private func content(for store: TypePaletteStore) -> some View {
        EditorPanelSection(
            title: "Type Library",
            description: "Reusable structs and enums can be attached to payload properties across states and events."
        ) {
            HStack(alignment: .top, spacing: 10) {
                ToolboxActionCard(
                    symbol: "square.stack.3d.up",
                    title: "Add Struct",
                    description: "Create a reusable payload struct that properties can reference.",
                    style: .inlineCompact
                ) {
                    store.send(.addStructTypeTapped)
                }

                ToolboxActionCard(
                    symbol: "point.3.connected.trianglepath.dotted",
                    title: "Add Enum",
                    description: "Create a reusable payload enum with named cases.",
                    style: .inlineCompact
                ) {
                    store.send(.addEnumTypeTapped)
                }
            }

            if store.types.isEmpty {
                Label("No reusable types yet. Add a struct or enum above when primitive payloads stop being enough.", systemImage: "square.stack.3d.up")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.types) { payloadType in
                        PaletteLibraryCard(
                            symbol: payloadType.paletteSymbol,
                            symbolColor: payloadType.paletteColor,
                            title: payloadType.name,
                            subtitle: payloadType.librarySummary,
                            isSelected: selectedTypeID == payloadType.id,
                            isDeleteEnabled: !(store.definition?.typeIsReferenced(payloadType.id) ?? false),
                            deleteHelp: store.definition?.typeIsReferenced(payloadType.id) ?? false
                                ? "Remove references to this type before deleting it."
                                : "Delete type"
                        ) {
                            store.send(.selectType(id: payloadType.id))
                        } onDelete: {
                            store.send(.deleteType(id: payloadType.id))
                        }
                    }
                }
            }
        }
    }
}
