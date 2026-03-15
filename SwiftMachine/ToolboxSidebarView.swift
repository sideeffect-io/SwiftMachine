//
//  ToolboxSidebarView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct ToolboxSidebarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EditorShellMetrics.panelSpacing) {
                header

                ToolboxSectionPlaceholder(
                    title: "Creation Surface",
                    description: "This sidebar will host the tools used to add elements to the state machine."
                ) {
                    ToolboxCardPlaceholder(
                        symbol: "circle.hexagongrid",
                        title: "State Nodes",
                        description: "Placeholder for future state creation tools."
                    )

                    ToolboxCardPlaceholder(
                        symbol: "arrow.triangle.branch",
                        title: "Transitions",
                        description: "Placeholder for future transition and connection tools."
                    )
                }

                ToolboxSectionPlaceholder(
                    title: "Editing Workflow",
                    description: "Secondary actions and inspectors will be added once the base editor interactions exist."
                ) {
                    ToolboxCardPlaceholder(
                        symbol: "slider.horizontal.3",
                        title: "Properties",
                        description: "Reserved for the next phase of machine editing controls."
                    )
                }

                footerNote
            }
            .padding(EditorShellMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Toolbox", systemImage: "shippingbox")
                .font(.title2.weight(.semibold))

            Text("The left panel is ready for future machine-building tools. This pass only establishes the toolbox area and its structure.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerNote: some View {
        Label("All cards are placeholders until tool behaviors are implemented.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .controlBackgroundColor),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ToolboxSectionPlaceholder<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: EditorShellMetrics.cardSpacing) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: EditorShellMetrics.cardSpacing) {
                content
            }
        }
        .padding(EditorShellMetrics.cardPadding)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: EditorShellMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EditorShellMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ToolboxCardPlaceholder: View {
    let symbol: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(EditorShellMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

#Preview {
    ToolboxSidebarView()
        .frame(width: EditorShellMetrics.sidebarIdealWidth, height: 700)
}
