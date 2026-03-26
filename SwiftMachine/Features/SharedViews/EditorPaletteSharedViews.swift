//
//  EditorPaletteSharedViews.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import SwiftUI

struct PaletteLibraryCard: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    var isSelected = false
    var isDeleteEnabled = true
    var deleteHelp = "Delete item"
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .foregroundStyle(symbolColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.body.weight(.semibold))

                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .padding(.trailing, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(cardStroke, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDeleteEnabled ? Color.red : .secondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
            .disabled(!isDeleteEnabled)
            .help(deleteHelp)
        }
    }

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
    }

    private var cardStroke: Color {
        isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08)
    }
}

struct ToolboxActionCard: View {
    enum Style {
        case regular
        case compact
        case inlineCompact

        var horizontalSpacing: CGFloat {
            switch self {
            case .regular:
                return 12
            case .compact:
                return 10
            case .inlineCompact:
                return 8
            }
        }

        var contentSpacing: CGFloat {
            switch self {
            case .regular:
                return 4
            case .compact:
                return 2
            case .inlineCompact:
                return 0
            }
        }

        var iconFont: Font {
            switch self {
            case .regular:
                return .title3
            case .compact:
                return .body.weight(.semibold)
            case .inlineCompact:
                return .footnote.weight(.semibold)
            }
        }

        var iconWidth: CGFloat {
            switch self {
            case .regular:
                return 28
            case .compact:
                return 22
            case .inlineCompact:
                return 16
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular:
                return SwiftMachineShellMetrics.cardPadding
            case .compact:
                return 12
            case .inlineCompact:
                return 10
            }
        }

        var descriptionLineLimit: Int? {
            switch self {
            case .regular:
                return nil
            case .compact:
                return 2
            case .inlineCompact:
                return nil
            }
        }

        var showsDescription: Bool {
            switch self {
            case .regular, .compact:
                return true
            case .inlineCompact:
                return false
            }
        }

        var titleFont: Font {
            switch self {
            case .regular, .compact:
                return .body.weight(.semibold)
            case .inlineCompact:
                return .footnote.weight(.semibold)
            }
        }

        var verticalAlignment: VerticalAlignment {
            switch self {
            case .regular, .compact:
                return .top
            case .inlineCompact:
                return .center
            }
        }
    }

    let symbol: String
    let title: String
    let description: String
    var style: Style = .regular
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: style.verticalAlignment, spacing: style.horizontalSpacing) {
                Image(systemName: symbol)
                    .font(style.iconFont)
                    .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                    .frame(width: style.iconWidth)

                VStack(alignment: .leading, spacing: style.contentSpacing) {
                    Text(title)
                        .font(style.titleFont)

                    if style.showsDescription {
                        Text(description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(style.descriptionLineLimit)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(style.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .help(description)
    }
}

extension PayloadTypeDefinition {
    var paletteSymbol: String {
        switch kind {
        case .structType:
            return "square.stack.3d.up.fill"
        case .enumType:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    var paletteColor: Color {
        switch kind {
        case .structType:
            return .green
        case .enumType:
            return .purple
        }
    }

    var librarySummary: String {
        switch kind {
        case .structType(let fields):
            return fields.isEmpty
                ? "Struct, no fields"
                : "Struct, \(fields.count) field\(fields.count == 1 ? "" : "s")"
        case .enumType(let cases, let defaultCaseID):
            let defaultSummary = defaultCaseID == nil ? "no default" : "default case"
            return cases.isEmpty
                ? "Enum, no cases"
                : "Enum, \(cases.count) case\(cases.count == 1 ? "" : "s"), \(defaultSummary)"
        }
    }
}
