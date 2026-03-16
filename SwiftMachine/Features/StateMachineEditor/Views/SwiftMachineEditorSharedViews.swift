//
//  SwiftMachineEditorSharedViews.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct EditorPanelSection<Content: View>: View {
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

struct EditorInfoRow: View {
    let label: String
    let value: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            Text(label)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }
}

struct EditorBadge: View {
    let text: String
    let tint: Color
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
            }

            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14), in: Capsule())
        .foregroundStyle(tint)
    }
}

struct PropertyDefaultValueDraft: Equatable {
    var isEnabled: Bool
    var stringValue: String
    var integerValue: String
    var doubleValue: String
    var booleanValue: Bool

    nonisolated init(defaultValue: LiteralValue? = nil) {
        switch defaultValue {
        case .string(let value):
            isEnabled = true
            stringValue = value
            integerValue = ""
            doubleValue = ""
            booleanValue = false
        case .integer(let value):
            isEnabled = true
            stringValue = ""
            integerValue = String(value)
            doubleValue = ""
            booleanValue = false
        case .double(let value):
            isEnabled = true
            stringValue = ""
            integerValue = ""
            doubleValue = String(value)
            booleanValue = false
        case .boolean(let value):
            isEnabled = true
            stringValue = ""
            integerValue = ""
            doubleValue = ""
            booleanValue = value
        case nil:
            isEnabled = false
            stringValue = ""
            integerValue = ""
            doubleValue = ""
            booleanValue = false
        }
    }

    nonisolated func literalValue(for type: PropertyType) -> LiteralValue? {
        guard isEnabled else {
            return nil
        }

        switch type {
        case .string:
            return .string(stringValue)
        case .integer:
            guard let value = Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return .integer(value)
        case .double:
            guard let value = Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return .double(value)
        case .boolean:
            return .boolean(booleanValue)
        }
    }

    nonisolated func validationMessage(
        for type: PropertyType,
        propertyName: String? = nil
    ) -> String? {
        guard isEnabled else {
            return nil
        }

        let trimmedPropertyName = propertyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = trimmedPropertyName.isEmpty ? "This property" : "Property '\(trimmedPropertyName)'"

        switch type {
        case .string, .boolean:
            return nil
        case .integer:
            guard Int(integerValue.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                return "\(subject) needs a valid integer default value."
            }
            return nil
        case .double:
            guard Double(doubleValue.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                return "\(subject) needs a valid double default value."
            }
            return nil
        }
    }
}

struct PropertyDefaultValueEditor: View {
    let type: PropertyType
    @Binding var draft: PropertyDefaultValueDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Default Value", isOn: $draft.isEnabled)
                .toggleStyle(.switch)

            if draft.isEnabled {
                inputField
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch type {
        case .string:
            TextField("Default string", text: $draft.stringValue, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
        case .integer:
            TextField("Default integer", text: $draft.integerValue)
                .textFieldStyle(.roundedBorder)
        case .double:
            TextField("Default double", text: $draft.doubleValue)
                .textFieldStyle(.roundedBorder)
        case .boolean:
            Picker("Default value", selection: $draft.booleanValue) {
                Text("False")
                    .tag(false)
                Text("True")
                    .tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 200, alignment: .leading)
        }
    }
}

struct EditorPropertyListView: View {
    let properties: [PropertyDefinition]

    var body: some View {
        EditorTagFlowLayout(spacing: 8) {
            ForEach(properties) { property in
                EditorBadge(
                    text: property.editorLabel,
                    tint: property.isOptional ? .purple : .blue
                )
            }
        }
    }
}

struct EditorTagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let fittingWidth = proposal.width ?? 320
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentRowWidth + size.width > fittingWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        totalHeight += currentRowHeight

        return CGSize(width: fittingWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += currentRowHeight + spacing
                currentRowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

extension PropertyDefinition {
    var editorLabel: String {
        let baseLabel = "\(name): \(type.rawValue)\(isOptional ? "?" : "")"

        guard let defaultValue else {
            return baseLabel
        }

        return "\(baseLabel) = \(defaultValue.editorValueLabel)"
    }
}

private extension LiteralValue {
    var editorValueLabel: String {
        switch self {
        case .string(let value):
            return String(reflecting: value)
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        }
    }
}
