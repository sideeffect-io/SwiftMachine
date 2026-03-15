//
//  SwiftMachineToolboxView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct SwiftMachineToolboxView: View {
    @Environment(SwiftMachineStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.panelSpacing) {
                header

                if let stateMachine = designingStateMachine {
                    ToolboxSection(
                        title: "Definition",
                        description: "Tool actions send events to the editor state machine and mutate the in-memory definition."
                    ) {
                        SummaryPill(symbol: "point.3.connected.trianglepath.dotted", title: "Machine", value: stateMachine.name)
                        SummaryPill(symbol: "circle.hexagongrid", title: "States", value: "\(stateMachine.states.count)")
                        SummaryPill(symbol: "bolt.horizontal.circle", title: "Events", value: "\(stateMachine.events.count)")
                        SummaryPill(symbol: "arrow.triangle.branch", title: "Transitions", value: "\(stateMachine.transitions.count)")
                    }

                    ToolboxSection(
                        title: "Create Elements",
                        description: "The current slice supports direct state and event creation from the sidebar."
                    ) {
                        ToolboxActionCard(
                            symbol: "circle.hexagongrid",
                            title: "Add State",
                            description: "Append a new state to the machine definition."
                        ) {
                            store.send(.addNewState)
                        }

                        ToolboxActionCard(
                            symbol: "bolt.horizontal.circle",
                            title: "Add Event",
                            description: "Append a new event to the machine definition."
                        ) {
                            store.send(.addNewEvent)
                        }

                        ToolboxActionCard(
                            symbol: "arrow.triangle.branch",
                            title: "Add Transition",
                            description: "Transition creation needs source, event, and target selection, so it remains disabled for now.",
                            isEnabled: false
                        ) {}
                    }
                } else {
                    ToolboxSection(
                        title: "Wizard",
                        description: "The toolbox activates after the machine name and initial state have been provided."
                    ) {
                        SummaryPill(symbol: "square.and.pencil", title: "Status", value: "Waiting for setup")
                    }
                }

                footerNote
            }
            .padding(SwiftMachineShellMetrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
    }

    private var designingStateMachine: StateMachineDefinition? {
        guard case .designing(let stateMachine) = store.state else {
            return nil
        }

        return stateMachine
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Toolbox", systemImage: "shippingbox")
                .font(.title2.weight(.semibold))

            Text("The left panel dispatches editor events once the wizard has produced a valid state machine definition.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerNote: some View {
        Label("New states and events are created immediately. Transition authoring lands in the next editing slice.", systemImage: "info.circle")
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

private struct ToolboxSection<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.cardSpacing) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: SwiftMachineShellMetrics.cardSpacing) {
                content
            }
        }
        .padding(SwiftMachineShellMetrics.cardPadding)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SwiftMachineShellMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ToolboxActionCard: View {
    let symbol: String
    let title: String
    let description: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
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
            .padding(SwiftMachineShellMetrics.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isEnabled ? 0.05 : 0.025))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.08 : 0.04), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct SummaryPill: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.semibold)
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

#Preview {
    SwiftMachineToolboxView()
        .environment(
            SwiftMachineStore()
        )
        .frame(width: SwiftMachineShellMetrics.sidebarIdealWidth, height: 700)
}
