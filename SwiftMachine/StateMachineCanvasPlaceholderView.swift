//
//  StateMachineCanvasPlaceholderView.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import SwiftUI

struct StateMachineCanvasPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            CanvasGridBackground()

            VStack {
                header
                Spacer()
            }
            .padding(EditorShellMetrics.canvasInset)

            centeredPlaceholder
                .padding(EditorShellMetrics.canvasInset)
        }
        .overlay {
            RoundedRectangle(cornerRadius: EditorShellMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                .padding(EditorShellMetrics.canvasInset / 2)
        }
        .clipped()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("State Machine Canvas")
                    .font(.headline)

                Text("This workspace will host the visual Mealy state machine editor.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var centeredPlaceholder: some View {
        VStack(spacing: EditorShellMetrics.cardSpacing) {
            Image(systemName: "square.on.circle.dashed")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Canvas shell in place")
                .font(.title3.weight(.semibold))

            Text("Future states, transitions, and layout interactions will be rendered here. This pass only establishes the editor surface.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Label("Tool behaviors are intentionally not implemented yet", systemImage: "hammer")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: EditorShellMetrics.placeholderWidth)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

private struct CanvasGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let minorPath = gridPath(in: size, step: EditorShellMetrics.gridStep)
            let majorPath = gridPath(
                in: size,
                step: EditorShellMetrics.gridStep * CGFloat(EditorShellMetrics.majorGridFrequency)
            )

            context.stroke(minorPath, with: .color(Color.primary.opacity(0.045)), lineWidth: 0.5)
            context.stroke(majorPath, with: .color(Color.primary.opacity(0.08)), lineWidth: 0.8)
        }
    }

    private func gridPath(in size: CGSize, step: CGFloat) -> Path {
        var path = Path()
        var x: CGFloat = 0
        var y: CGFloat = 0

        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }

        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }

        return path
    }
}

#Preview {
    StateMachineCanvasPlaceholderView()
        .frame(width: 900, height: 700)
}
