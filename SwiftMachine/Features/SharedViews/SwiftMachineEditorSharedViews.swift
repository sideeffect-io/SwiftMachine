//
//  SwiftMachineEditorSharedViews.swift
//  SwiftMachine
//
//  Created by Codex on 16/03/2026.
//

import SwiftUI

struct EditorPanelSection<Content: View>: View {
    enum Density {
        case regular
        case compact

        var spacing: CGFloat {
            switch self {
            case .regular:
                return SwiftMachineShellMetrics.cardSpacing
            case .compact:
                return 8
            }
        }

        var padding: CGFloat {
            switch self {
            case .regular:
                return SwiftMachineShellMetrics.cardPadding
            case .compact:
                return 14
            }
        }

        var descriptionFont: Font {
            switch self {
            case .regular:
                return .subheadline
            case .compact:
                return .footnote
            }
        }
    }

    let title: String
    let description: String
    var density: Density = .regular
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(density.descriptionFont)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: density.spacing) {
                content
            }
        }
        .padding(density.padding)
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

struct PaletteInlineToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)

                configuration.label
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct PropertyDefaultValueEditor: View {
    enum Layout {
        case stacked
        case inline
    }

    let type: PropertyType
    @Binding var draft: PropertyDefaultValueDraft
    var layout: Layout = .stacked
    var showsToggle = true

    var body: some View {
        switch layout {
        case .stacked:
            VStack(alignment: .leading, spacing: 10) {
                if showsToggle {
                    defaultValueToggle
                }

                if draft.isEnabled {
                    stackedInputField
                }
            }

        case .inline:
            HStack(alignment: .center, spacing: 12) {
                if showsToggle {
                    defaultValueToggle
                        .fixedSize(horizontal: true, vertical: false)
                }

                if draft.isEnabled {
                    inlineInputField
                }
            }
        }
    }

    private var defaultValueToggle: some View {
        Toggle("Default Value", isOn: $draft.isEnabled)
            .toggleStyle(.switch)
    }

    @ViewBuilder
    private var stackedInputField: some View {
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
        case .model:
            EmptyView()
        }
    }

    @ViewBuilder
    private var inlineInputField: some View {
        switch type {
        case .string:
            TextField("Default string", text: $draft.stringValue)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        case .integer:
            TextField("Default integer", text: $draft.integerValue)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        case .double:
            TextField("Default double", text: $draft.doubleValue)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
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
        case .model:
            EmptyView()
        }
    }
}


struct EditorPropertyDraftRowView: View {
    enum LayoutStyle {
        case compact
        case adaptiveInline
        case paletteInline
        case inspectorCompact
    }

    @Binding var propertyDraft: EditorPropertyDraft
    var availableModelTypes: [PayloadTypeDefinition] = []
    var layout: LayoutStyle = .compact
    var showsDefaultValue = true
    var onEditReferencedType: ((String) -> Void)? = nil
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Property name", text: $propertyDraft.name)
                .textFieldStyle(.roundedBorder)

            controlsLayout

            if showsDefaultValue && propertyDraft.defaultValue.isEnabled {
                PropertyDefaultEditorView(
                    draft: $propertyDraft.defaultValue,
                    typeDefinitions: availableModelTypes,
                    showsEnumCasePicker: !showsInlineEnumCaseControl
                )
            }

            if let referencedTypeID = propertyDraft.type.referencedTypeID {
                HStack(spacing: 10) {
                    EditorBadge(
                        text: "Reusable Model",
                        tint: .green
                    )

                    if let onEditReferencedType {
                        Button("Edit Type") {
                            onEditReferencedType(referencedTypeID)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .onAppear {
            propertyDraft.reconfigureDefaultValue(availableModelTypes: availableModelTypes)
        }
        .onChange(of: propertyDraft.type) { _, _ in
            propertyDraft.reconfigureDefaultValue(availableModelTypes: availableModelTypes)
        }
        .onChange(of: availableModelTypes) { _, updatedTypes in
            propertyDraft.reconfigureDefaultValue(availableModelTypes: updatedTypes)
        }
    }

    @ViewBuilder
    private var controlsLayout: some View {
        switch layout {
        case .compact:
            compactControlLayout
        case .adaptiveInline:
            ViewThatFits(in: .horizontal) {
                inlineControlLayout
                compactControlLayout
            }
        case .paletteInline:
            paletteInlineControlLayout
        case .inspectorCompact:
            inspectorCompactControlLayout
        }
    }

    private var inlineControlLayout: some View {
        HStack(alignment: .bottom, spacing: 6) {
            typeControl
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            optionalControl

            if showsDefaultValue {
                defaultControl
            }
        }
        .padding(.trailing, 30)
        .overlay(alignment: .bottomTrailing) {
            removeButton
        }
    }

    private var compactControlLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            typeControl
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 12) {
                optionalControl

                if showsDefaultValue {
                    defaultControl
                }

                Spacer(minLength: 0)

                removeButton
            }
        }
    }

    private var inspectorCompactControlLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            typeControl
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: 12) {
                optionalControl

                if showsDefaultValue {
                    defaultControl
                }

                if showsInlineEnumCaseControl {
                    enumCaseControl
                        .frame(maxWidth: 180, alignment: .leading)
                }

                Spacer(minLength: 0)

                removeButton
            }
        }
    }

    private var paletteInlineControlLayout: some View {
        HStack(alignment: .center, spacing: SwiftMachineShellMetrics.paletteInlineControlSpacing) {
            paletteTypeControl
                .frame(width: SwiftMachineShellMetrics.paletteInlinePickerWidth, alignment: .leading)

            paletteOptionalControl

            if showsDefaultValue {
                paletteDefaultControl
            }

            Spacer(minLength: 0)

            removeButton
        }
    }

    private var typeControl: some View {
        EditorPropertyControlColumn(title: "Type") {
            PropertyTypePicker(
                selection: $propertyDraft.type,
                availableModelTypes: availableModelTypes
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var optionalControl: some View {
        EditorPropertyControlColumn(title: "Optional") {
            Toggle("", isOn: $propertyDraft.isOptional)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var defaultControl: some View {
        EditorPropertyControlColumn(title: "Default") {
            Toggle("", isOn: defaultValueToggleBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var removeButton: some View {
        Button(role: .destructive, action: remove) {
            Image(systemName: "minus.circle.fill")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .help("Remove property")
    }

    private var paletteTypeControl: some View {
        PropertyTypePicker(
            selection: $propertyDraft.type,
            availableModelTypes: availableModelTypes,
            controlSize: .small
        )
        .help("Property type")
    }

    private var paletteOptionalControl: some View {
        Toggle("Optional", isOn: $propertyDraft.isOptional)
            .toggleStyle(PaletteInlineToggleStyle())
            .fixedSize(horizontal: true, vertical: false)
            .help("Optional property")
    }

    private var paletteDefaultControl: some View {
        Toggle("Default", isOn: defaultValueToggleBinding)
            .toggleStyle(PaletteInlineToggleStyle())
            .fixedSize(horizontal: true, vertical: false)
            .help("Default value")
    }

    private var defaultValueToggleBinding: Binding<Bool> {
        Binding(
            get: { propertyDraft.defaultValue.isEnabled },
            set: { isEnabled in
                propertyDraft.defaultValue.setEnabled(isEnabled)
            }
        )
    }

    private var showsInlineEnumCaseControl: Bool {
        guard layout == .inspectorCompact,
              showsDefaultValue,
              propertyDraft.defaultValue.isEnabled,
              case .enumType = propertyDraft.defaultValue.targetSchema else {
            return false
        }

        return true
    }

    private var enumCaseControl: some View {
        Group {
            if case .enumType(let cases, _) = propertyDraft.defaultValue.targetSchema {
                EditorPropertyControlColumn(title: "Case") {
                    Picker(
                        "Case",
                        selection: Binding(
                            get: { propertyDraft.defaultValue.selectedEnumCaseID ?? cases.first?.id ?? "" },
                            set: { newCaseID in
                                propertyDraft.defaultValue.selectEnumCase(
                                    newCaseID,
                                    cases: cases
                                )
                            }
                        )
                    ) {
                        ForEach(cases) { payloadCase in
                            Text(payloadCase.name)
                                .tag(payloadCase.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

struct PropertyTypePicker: View {
    @Binding var selection: PropertyType
    let availableModelTypes: [PayloadTypeDefinition]
    var controlSize: ControlSize = .regular

    var body: some View {
        Picker("Property type", selection: $selection) {
            if !availableModelTypes.isEmpty {
                Section("Primitives") {
                    primitiveItems
                }

                Section("Models") {
                    modelItems
                }
            } else {
                primitiveItems
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(controlSize)
    }

    private var primitiveItems: some View {
        ForEach(PropertyType.primitiveCases, id: \.self) { propertyType in
            Text(propertyType.title)
                .tag(propertyType)
        }
    }

    private var modelItems: some View {
        ForEach(availableModelTypes) { modelType in
            Text("\(modelType.name) (\(modelType.kindTitle))")
                .tag(PropertyType.model(typeID: modelType.id))
        }
    }
}

struct EditorPropertyControlColumn<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            content
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

private struct PropertyDefaultEditorView: View {
    @Binding var draft: PropertyDefaultDraft
    let typeDefinitions: [PayloadTypeDefinition]
    var showsEnumCasePicker = true

    var body: some View {
        switch draft.targetSchema {
        case .primitive(let primitiveType):
            PropertyDefaultValueEditor(
                type: primitiveType,
                draft: $draft.literalDraft,
                showsToggle: false
            )

        case .structType:
            VStack(alignment: .leading, spacing: 10) {
                ForEach($draft.fieldDrafts) { $fieldDraft in
                    PropertyDefaultNestedValueRowView(
                        title: fieldDraft.field.name,
                        subtitle: fieldDraft.field.fieldLabel(typeDefinitions: typeDefinitions),
                        draft: $fieldDraft.valueDraft,
                        typeDefinitions: typeDefinitions,
                        showsToggle: fieldDraft.field.isOptional
                    )
                }
            }

        case .enumType(let cases, _):
            VStack(alignment: .leading, spacing: 10) {
                if showsEnumCasePicker {
                    EditorPropertyControlColumn(title: "Case") {
                        Picker(
                            "Case",
                            selection: Binding(
                                get: { draft.selectedEnumCaseID ?? cases.first?.id ?? "" },
                                set: { newCaseID in
                                    draft.selectEnumCase(
                                        newCaseID,
                                        cases: cases
                                    )
                                }
                            )
                        ) {
                            ForEach(cases) { payloadCase in
                                Text(payloadCase.name)
                                    .tag(payloadCase.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                if let payloadDraft = draft.payloadDrafts.first {
                    PropertyDefaultNestedValueRowView(
                        title: "Payload",
                        subtitle: payloadDraft.valueDraft.payloadLabel(typeDefinitions: typeDefinitions),
                        draft: Binding(
                            get: { draft.payloadDrafts.first?.valueDraft ?? payloadDraft.valueDraft },
                            set: { updatedDraft in
                                draft.payloadDrafts = [PropertyDefaultPayloadDraft(valueDraft: updatedDraft)]
                            }
                        ),
                        typeDefinitions: typeDefinitions
                    )
                }
            }
        }
    }
}

private struct PropertyDefaultNestedValueRowView: View {
    let title: String
    let subtitle: String
    @Binding var draft: PropertyDefaultDraft
    let typeDefinitions: [PayloadTypeDefinition]
    var showsToggle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if showsToggle {
                    Toggle("Set Value", isOn: setValueBinding)
                        .toggleStyle(PaletteInlineToggleStyle())
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            if draft.isEnabled {
                PropertyDefaultEditorView(
                    draft: $draft,
                    typeDefinitions: typeDefinitions
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var setValueBinding: Binding<Bool> {
        Binding(
            get: { draft.isEnabled },
            set: { isEnabled in
                draft.setEnabled(isEnabled)
            }
        )
    }
}
