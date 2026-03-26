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
        case .model:
            return nil
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
        case .model:
            return nil
        }
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

struct PropertyDefaultFieldDraft: Identifiable, Equatable {
    let field: ResolvedPropertyField
    var valueDraft: PropertyDefaultDraft

    var id: String {
        field.id
    }
}

struct PropertyDefaultPayloadDraft: Identifiable, Equatable {
    let id = "payload"
    var valueDraft: PropertyDefaultDraft
}

struct PropertyDefaultDraft: Equatable {
    let targetName: String
    let targetType: PropertyType
    let targetSchema: ResolvedPropertySchema
    var isEnabled: Bool
    var literalDraft: PropertyDefaultValueDraft
    var fieldDrafts: [PropertyDefaultFieldDraft]
    var selectedEnumCaseID: String?
    var payloadDrafts: [PropertyDefaultPayloadDraft]

    nonisolated init(
        targetName: String,
        targetType: PropertyType,
        targetSchema: ResolvedPropertySchema,
        defaultValue: PropertyDefaultValue?,
        isRequired: Bool = false
    ) {
        self.targetName = targetName
        self.targetType = targetType
        self.targetSchema = targetSchema

        switch defaultValue {
        case .string(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .string(value))
        case .integer(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .integer(value))
        case .double(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .double(value))
        case .boolean(let value):
            literalDraft = PropertyDefaultValueDraft(defaultValue: .boolean(value))
        default:
            literalDraft = .init()
        }

        isEnabled = defaultValue != nil || isRequired

        switch targetSchema {
        case .primitive:
            fieldDrafts = []
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .structType(let fields):
            let existingFields: [String: PropertyDefaultFieldValue]
            if case .structValue(let storedFields) = defaultValue {
                existingFields = storedFields.reduce(into: [:]) { partialResult, field in
                    guard partialResult[field.fieldID] == nil else {
                        return
                    }

                    partialResult[field.fieldID] = field
                }
            } else {
                existingFields = [:]
            }

            fieldDrafts = fields.map { field in
                PropertyDefaultFieldDraft(
                    field: field,
                    valueDraft: PropertyDefaultDraft(
                        targetName: field.name,
                        targetType: field.type,
                        targetSchema: field.schema,
                        defaultValue: existingFields[field.id]?.value,
                        isRequired: !field.isOptional
                    )
                )
            }
            selectedEnumCaseID = nil
            payloadDrafts = []

        case .enumType(let cases, let defaultCaseID):
            fieldDrafts = []

            if case .enumCase(let caseID, let payload) = defaultValue,
               cases.contains(where: { $0.id == caseID }) {
                selectedEnumCaseID = caseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: caseID,
                    cases: cases,
                    defaultValue: payload
                )
            } else {
                let preferredCaseID = defaultCaseID ?? cases.first?.id
                selectedEnumCaseID = preferredCaseID
                payloadDrafts = Self.payloadDrafts(
                    caseID: preferredCaseID,
                    cases: cases,
                    defaultValue: nil
                )
            }
        }

        if isEnabled {
            activateEditorInputs()
        }
    }

    nonisolated var propertyDefaultValue: PropertyDefaultValue? {
        guard isEnabled else {
            return nil
        }

        switch targetSchema {
        case .primitive(let primitiveType):
            guard let literalValue = literalDraft.literalValue(for: primitiveType) else {
                return nil
            }

            switch literalValue {
            case .string(let value):
                return .string(value)
            case .integer(let value):
                return .integer(value)
            case .double(let value):
                return .double(value)
            case .boolean(let value):
                return .boolean(value)
            }

        case .structType:
            return .structValue(
                fields: fieldDrafts.compactMap { fieldDraft in
                    guard let fieldValue = fieldDraft.valueDraft.propertyDefaultValue else {
                        return nil
                    }

                    return PropertyDefaultFieldValue(
                        fieldID: fieldDraft.field.id,
                        value: fieldValue
                    )
                }
            )

        case .enumType:
            return .enumCase(
                caseID: selectedEnumCaseID ?? "",
                payload: payloadDrafts.first?.valueDraft.propertyDefaultValue
            )
        }
    }

    func validationMessage(propertyName: String) -> String? {
        guard isEnabled else {
            return nil
        }

        switch targetSchema {
        case .primitive(let primitiveType):
            return literalDraft.validationMessage(
                for: primitiveType,
                propertyName: propertyName
            )

        case .structType(let fields):
            let fieldDraftsByID = fieldDrafts.reduce(into: [String: PropertyDefaultFieldDraft]()) { partialResult, fieldDraft in
                partialResult[fieldDraft.field.id] = fieldDraft
            }

            for field in fields {
                guard let fieldDraft = fieldDraftsByID[field.id] else {
                    continue
                }

                if !field.isOptional && fieldDraft.valueDraft.propertyDefaultValue == nil {
                    return "Property '\(propertyName)' needs a default value for field '\(field.name)'."
                }

                if let childMessage = fieldDraft.valueDraft.validationMessage(propertyName: field.name) {
                    return childMessage
                }
            }

            return nil

        case .enumType(let cases, _):
            guard let selectedEnumCaseID,
                  let resolvedCase = cases.first(where: { $0.id == selectedEnumCaseID }) else {
                return "Property '\(propertyName)' needs a selected enum case."
            }

            guard resolvedCase.payloadSchema != nil else {
                return nil
            }

            guard let payloadDraft = payloadDrafts.first else {
                return "Property '\(propertyName)' needs a payload default for case '\(resolvedCase.name)'."
            }

            if payloadDraft.valueDraft.propertyDefaultValue == nil {
                return payloadDraft.valueDraft.validationMessage(propertyName: resolvedCase.name)
                    ?? "Property '\(propertyName)' needs a payload default for case '\(resolvedCase.name)'."
            }

            return payloadDraft.valueDraft.validationMessage(propertyName: resolvedCase.name)
        }
    }

    nonisolated mutating func selectEnumCase(
        _ caseID: String,
        cases: [ResolvedEnumCase]
    ) {
        selectedEnumCaseID = caseID
        let existingPayload = payloadDrafts.first?.valueDraft.propertyDefaultValue
        payloadDrafts = Self.payloadDrafts(
            caseID: caseID,
            cases: cases,
            defaultValue: existingPayload
        )
    }

    nonisolated mutating func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled

        guard isEnabled else {
            return
        }

        activateEditorInputs()
    }

    nonisolated private static func payloadDrafts(
        caseID: String?,
        cases: [ResolvedEnumCase],
        defaultValue: PropertyDefaultValue?
    ) -> [PropertyDefaultPayloadDraft] {
        guard let caseID,
              let resolvedCase = cases.first(where: { $0.id == caseID }),
              let payloadSchema = resolvedCase.payloadSchema else {
            return []
        }

        return [
            PropertyDefaultPayloadDraft(
                valueDraft: PropertyDefaultDraft(
                    targetName: resolvedCase.name,
                    targetType: resolvedCase.payloadType ?? .string,
                    targetSchema: payloadSchema,
                    defaultValue: defaultValue,
                    isRequired: true
                )
            )
        ]
    }

    nonisolated private mutating func activateEditorInputs() {
        switch targetSchema {
        case .primitive:
            literalDraft.isEnabled = true

        case .structType:
            for index in fieldDrafts.indices {
                guard fieldDrafts[index].valueDraft.isEnabled else {
                    continue
                }

                fieldDrafts[index].valueDraft.activateEditorInputs()
            }

        case .enumType:
            guard let firstPayloadIndex = payloadDrafts.indices.first else {
                return
            }

            payloadDrafts[firstPayloadIndex].valueDraft.setEnabled(true)
        }
    }
}

struct EditorPropertyDraft: Identifiable, Equatable {
    let id: String
    var name: String
    var type: PropertyType
    var isOptional: Bool
    var defaultValue: PropertyDefaultDraft

    nonisolated init(
        id: String = UUID().uuidString,
        name: String = "",
        type: PropertyType = .string,
        isOptional: Bool = false,
        defaultValue: PropertyDefaultDraft? = nil
    ) {
        let fallbackDefaultValue = defaultValue ?? PropertyDefaultDraft(
            targetName: name,
            targetType: type,
            targetSchema: .primitive(type: type.isPrimitive ? type : .string),
            defaultValue: nil
        )
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.defaultValue = fallbackDefaultValue
    }

    nonisolated init(
        property: PropertyDefinition,
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        let schemaDefinition = propertySchemaDefinition(types: availableModelTypes)
        let propertySchema = schemaDefinition.schema(for: property.type)

        self.init(
            id: property.id,
            name: property.name,
            type: property.type,
            isOptional: property.isOptional,
            defaultValue: propertySchema.map { schema in
                PropertyDefaultDraft(
                    targetName: property.name,
                    targetType: property.type,
                    targetSchema: schema,
                    defaultValue: property.defaultValue
                )
            }
        )
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var propertyDefinition: PropertyDefinition {
        PropertyDefinition(
            id: id,
            name: trimmedName,
            type: type,
            isOptional: isOptional,
            defaultValue: defaultValue.propertyDefaultValue
        )
    }

    var defaultValueValidationMessage: String? {
        defaultValue.validationMessage(
            propertyName: trimmedName
        )
    }

    mutating func reconfigureDefaultValue(
        availableModelTypes: [PayloadTypeDefinition]
    ) {
        let schemaDefinition = propertySchemaDefinition(types: availableModelTypes)
        guard let propertySchema = schemaDefinition.schema(for: type) else {
            defaultValue = PropertyDefaultDraft(
                targetName: trimmedName.isEmpty ? name : trimmedName,
                targetType: type,
                targetSchema: .primitive(type: type.isPrimitive ? type : .string),
                defaultValue: nil
            )
            return
        }

        defaultValue = PropertyDefaultDraft(
            targetName: trimmedName.isEmpty ? name : trimmedName,
            targetType: type,
            targetSchema: propertySchema,
            defaultValue: defaultValue.propertyDefaultValue
        )
    }
}

extension Array where Element == EditorPropertyDraft {
    var propertyDefinitions: [PropertyDefinition] {
        map(\.propertyDefinition)
    }

    func validationMessage(
        emptyNameMessage: String,
        duplicateNameMessage: String
    ) -> String? {
        let trimmedPropertyNames = map(\.trimmedName)

        if trimmedPropertyNames.contains(where: \.isEmpty) {
            return emptyNameMessage
        }

        if Set(trimmedPropertyNames).count != trimmedPropertyNames.count {
            return duplicateNameMessage
        }

        if let defaultValueValidationMessage = compactMap(\.defaultValueValidationMessage).first {
            return defaultValueValidationMessage
        }

        return nil
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

extension PropertyDefinition {
    nonisolated var editorLabel: String {
        editorLabel(typeDefinitions: [])
    }

    nonisolated func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        let baseLabel = "\(name): \(type.editorLabel(typeDefinitions: typeDefinitions))\(isOptional ? "?" : "")"

        guard let defaultValue else {
            return baseLabel
        }

        return "\(baseLabel) = \(defaultValue.editorValueLabel(for: type, typeDefinitions: typeDefinitions))"
    }
}

extension PropertyType {
    nonisolated func editorLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        switch self {
        case .string, .integer, .double, .boolean:
            return rawValue
        case .model(let typeID):
            return typeDefinitions.first(where: { $0.id == typeID })?.name ?? "missing type"
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

private extension ResolvedPropertyField {
    nonisolated func fieldLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        let property = PropertyDefinition(
            id: id,
            name: name,
            type: type,
            isOptional: isOptional
        )

        return property.editorLabel(typeDefinitions: typeDefinitions)
    }
}

private extension PropertyDefaultDraft {
    nonisolated func payloadLabel(typeDefinitions: [PayloadTypeDefinition]) -> String {
        switch targetSchema {
        case .primitive(let type):
            return "Payload: \(type.editorLabel(typeDefinitions: typeDefinitions))"
        case .structType:
            return "Payload fields"
        case .enumType:
            return "Nested enum payload"
        }
    }
}

private extension PropertyDefaultValue {
    nonisolated func editorValueLabel(
        for type: PropertyType,
        typeDefinitions: [PayloadTypeDefinition]
    ) -> String {
        let schemaDefinition = propertySchemaDefinition(types: typeDefinitions)
        let propertySchema = schemaDefinition.schema(for: type)

        switch self {
        case .string(let value):
            return String(reflecting: value)
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .structValue(let fields):
            guard case .structType(let resolvedFields)? = propertySchema else {
                return "{\(fields.count) field\(fields.count == 1 ? "" : "s")}"
            }

            let fieldNames = resolvedFields.reduce(into: [String: String]()) { partialResult, field in
                partialResult[field.id] = field.name
            }

            let summary = fields.map { field in
                fieldNames[field.fieldID] ?? "field"
            }
            .joined(separator: ", ")

            return "{\(summary)}"
        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _)? = propertySchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return ".unknown"
            }

            guard let payload else {
                return ".\(resolvedCase.name)"
            }

            let payloadType = resolvedCase.payloadType ?? .string
            return ".\(resolvedCase.name)(\(payload.editorValueLabel(for: payloadType, typeDefinitions: typeDefinitions)))"
        }
    }
}

nonisolated private func propertySchemaDefinition(
    types: [PayloadTypeDefinition]
) -> StateMachineDefinition {
    StateMachineDefinition(
        id: "property-defaults",
        name: "Property Defaults",
        initialStateID: "property-defaults-state",
        types: types,
        states: [],
        events: [],
        transitions: []
    )
}
