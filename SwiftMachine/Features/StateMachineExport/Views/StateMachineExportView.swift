//
//  StateMachineExportView.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import SwiftUI

struct StateMachineExportView: View {
    @Environment(\.stateMachineExportStoreFactory) private var stateMachineExportStoreFactory

    var body: some View {
        WithViewStore(store: stateMachineExportStoreFactory.make()) { store in
            content(for: store)
        }
    }

    private func content(for store: StateMachineExportStore) -> some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.cardSpacing) {
            Text("AI Export")
                .font(.headline)

            ToolboxActionCard(
                symbol: "square.and.arrow.down",
                title: "Export…",
                description: "",
                style: .inlineCompact,
                isEnabled: store.state.renderedExport != nil && !store.state.isSaving
            ) {
                store.send(.exportTapped)
            }
        }
        .padding(SwiftMachineShellMetrics.cardPadding)
        .background(
            .thinMaterial,
            in: RoundedRectangle(
                cornerRadius: SwiftMachineShellMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: SwiftMachineShellMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .sheet(isPresented: previewBinding(for: store)) {
            StateMachineExportPreviewSheet(store: store)
        }
    }

    private func previewBinding(for store: StateMachineExportStore) -> Binding<Bool> {
        Binding(
            get: { store.state.isPreviewPresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.dismissPreview)
                }
            }
        )
    }
}

private struct StateMachineExportPreviewSheet: View {
    let store: StateMachineExportStore

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let previewErrorMessage = store.state.previewErrorMessage {
                Label(previewErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
            }

            previewBody

            Divider()

            footer
        }
        .frame(minWidth: 760, minHeight: 560)
        .interactiveDismissDisabled(store.state.isSaving)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Markdown Export Preview")
                .font(.title3.weight(.semibold))

            Text("Review the exact Markdown that will be saved to disk. The preview is read-only so the export stays deterministic.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let renderedExport = store.state.renderedExport {
                HStack(spacing: 10) {
                    EditorBadge(
                        text: renderedExport.suggestedFilename,
                        tint: .blue,
                        symbol: "doc.plaintext"
                    )

                    EditorBadge(
                        text: "Revision \(renderedExport.revision)",
                        tint: .green,
                        symbol: "arrow.trianglehead.clockwise"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    @ViewBuilder
    private var previewBody: some View {
        if let renderedExport = store.state.renderedExport {
            ScrollView([.horizontal, .vertical]) {
                Text(verbatim: renderedExport.markdown)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Color(nsColor: .textBackgroundColor))
        } else {
            ContentUnavailableView(
                "No Export Available",
                systemImage: "doc.text.magnifyingglass",
                description: Text("The machine definition is no longer available.")
            )
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                store.send(.dismissPreview)
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Save Markdown…") {
                store.send(.saveTapped)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.state.renderedExport == nil || store.state.isSaving)
        }
        .padding(20)
    }
}
