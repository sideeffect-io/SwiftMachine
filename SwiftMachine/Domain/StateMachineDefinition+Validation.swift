//
//  StateMachineDefinition+Validation.swift
//  SwiftMachine
//
//  Created by Codex on 15/03/2026.
//

import Foundation

extension StateMachineDefinition {
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        func orderedDuplicates(in values: [String]) -> [String] {
            var seen = Set<String>()
            var duplicates = Set<String>()
            var orderedDuplicates: [String] = []

            for value in values {
                if !seen.insert(value).inserted && duplicates.insert(value).inserted {
                    orderedDuplicates.append(value)
                }
            }

            return orderedDuplicates
        }

        let stateIDs = orderedDuplicates(in: states.map(\.id))
        let stateNames = orderedDuplicates(in: states.map(\.name))
        let eventIDs = orderedDuplicates(in: events.map(\.id))
        let eventNames = orderedDuplicates(in: events.map(\.name))
        let typeIDs = orderedDuplicates(in: types.map(\.id))
        let typeNames = orderedDuplicates(in: types.map(\.name))
        let knownStateIDs = Set(states.map(\.id))
        let knownEventIDs = Set(events.map(\.id))
        let knownTypeIDs = Set(types.map(\.id))
        let statePropertiesByStateID = states.reduce(into: [String: [String: PropertyDefinition]]()) { partialResult, state in
            guard partialResult[state.id] == nil else {
                return
            }

            partialResult[state.id] = state.properties.reduce(into: [String: PropertyDefinition]()) { propertyMap, property in
                guard propertyMap[property.id] == nil else {
                    return
                }

                propertyMap[property.id] = property
            }
        }
        let eventPropertiesByEventID = events.reduce(into: [String: [String: PropertyDefinition]]()) { partialResult, event in
            guard partialResult[event.id] == nil else {
                return
            }

            partialResult[event.id] = event.properties.reduce(into: [String: PropertyDefinition]()) { propertyMap, property in
                guard propertyMap[property.id] == nil else {
                    return
                }

                propertyMap[property.id] = property
            }
        }

        for state in states {
            if state.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStateID(stateName: state.name))
            }

            if state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStateName(stateID: state.id))
            }

            for duplicateName in orderedDuplicates(in: state.properties.map(\.name)) {
                errors.append(.duplicateStatePropertyName(stateID: state.id, propertyName: duplicateName))
            }

            validatePropertyDefinitions(
                state.properties,
                ownerID: state.id,
                knownTypeIDs: knownTypeIDs,
                errors: &errors
            )
        }

        for duplicateID in stateIDs {
            errors.append(.duplicateStateID(duplicateID))
        }

        for duplicateName in stateNames {
            errors.append(.duplicateStateName(duplicateName))
        }

        for event in events {
            if event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyEventID(eventName: event.name))
            }

            if event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyEventName(eventID: event.id))
            }

            for duplicateName in orderedDuplicates(in: event.properties.map(\.name)) {
                errors.append(.duplicateEventPropertyName(eventID: event.id, propertyName: duplicateName))
            }

            validatePropertyDefinitions(
                event.properties,
                ownerID: event.id,
                knownTypeIDs: knownTypeIDs,
                errors: &errors
            )
        }

        for duplicateID in eventIDs {
            errors.append(.duplicateEventID(duplicateID))
        }

        for duplicateName in eventNames {
            errors.append(.duplicateEventName(duplicateName))
        }

        for type in types {
            if type.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTypeID(typeName: type.name))
            }

            if type.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTypeName(typeID: type.id))
            }

            switch type.kind {
            case .structType(let fields):
                for duplicateName in orderedDuplicates(in: fields.map(\.name)) {
                    errors.append(.duplicateTypePropertyName(typeID: type.id, propertyName: duplicateName))
                }

                validatePropertyDefinitions(
                    fields,
                    ownerID: type.id,
                    knownTypeIDs: knownTypeIDs,
                    errors: &errors
                )

            case .enumType(let cases, let defaultCaseID):
                for payloadCase in cases where payloadCase.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    errors.append(.emptyTypeCaseName(typeID: type.id, caseID: payloadCase.id))
                }

                for duplicateName in orderedDuplicates(in: cases.map(\.name)) {
                    errors.append(.duplicateTypeCaseName(typeID: type.id, caseName: duplicateName))
                }

                if let defaultCaseID,
                   !cases.contains(where: { $0.id == defaultCaseID }) {
                    errors.append(.unknownTypeDefaultCase(typeID: type.id, caseID: defaultCaseID))
                }

                for payloadCase in cases {
                    if let payloadTypeID = payloadCase.payloadType?.referencedTypeID,
                       !knownTypeIDs.contains(payloadTypeID) {
                        errors.append(
                            .unknownPropertyTypeReference(
                                ownerID: type.id,
                                propertyID: payloadCase.id,
                                typeID: payloadTypeID
                            )
                        )
                    }
                }
            }
        }

        for duplicateID in typeIDs {
            errors.append(.duplicateTypeID(duplicateID))
        }

        for duplicateName in typeNames {
            errors.append(.duplicateTypeName(duplicateName))
        }

        var visiting = Set<String>()
        var visited = Set<String>()
        for type in types where !visited.contains(type.id) {
            validateTypeCycle(
                startingAt: type.id,
                visiting: &visiting,
                visited: &visited,
                errors: &errors
            )
        }

        if !knownStateIDs.contains(initialStateID) {
            errors.append(.unknownInitialState(initialStateID))
        }

        for transition in transitions {
            if !knownStateIDs.contains(transition.sourceStateID) {
                errors.append(.unknownTransitionSourceState(
                    transitionID: transition.id,
                    stateID: transition.sourceStateID
                ))
            }

            if !knownStateIDs.contains(transition.targetStateID) {
                errors.append(.unknownTransitionTargetState(
                    transitionID: transition.id,
                    stateID: transition.targetStateID
                ))
            }

            if !knownEventIDs.contains(transition.eventID) {
                errors.append(.unknownTransitionEvent(
                    transitionID: transition.id,
                    eventID: transition.eventID
                ))
            }

            for duplicateTargetPropertyID in orderedDuplicates(
                in: transition.targetStateCreation.assignments.map(\.targetPropertyID)
            ) {
                errors.append(
                    .duplicateTransitionTargetPropertyAssignment(
                        transitionID: transition.id,
                        propertyID: duplicateTargetPropertyID
                    )
                )
            }

            guard let targetProperties = statePropertiesByStateID[transition.targetStateID] else {
                continue
            }

            let sourceProperties = statePropertiesByStateID[transition.sourceStateID].map { Array($0.values) } ?? []
            let eventProperties = eventPropertiesByEventID[transition.eventID].map { Array($0.values) } ?? []

            for assignment in transition.targetStateCreation.assignments {
                guard let targetProperty = targetProperties[assignment.targetPropertyID] else {
                    errors.append(
                        .unknownTransitionTargetProperty(
                            transitionID: transition.id,
                            stateID: transition.targetStateID,
                            propertyID: assignment.targetPropertyID
                        )
                    )
                    continue
                }

                guard let targetSchema = schema(for: targetProperty) else {
                    continue
                }

                validateTransitionValueSource(
                    assignment.valueSource,
                    expectedType: targetProperty.type,
                    expectedSchema: targetSchema,
                    transitionID: transition.id,
                    targetPropertyID: targetProperty.id,
                    sourceStateID: transition.sourceStateID,
                    eventID: transition.eventID,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    errors: &errors
                )
            }
        }

        return errors
    }

    enum ValidationError: Error, Sendable, Equatable, Hashable {
        case emptyStateID(stateName: String)
        case emptyStateName(stateID: String)
        case duplicateStateID(String)
        case duplicateStateName(String)
        case emptyEventID(eventName: String)
        case emptyEventName(eventID: String)
        case duplicateEventID(String)
        case duplicateEventName(String)
        case emptyTypeID(typeName: String)
        case emptyTypeName(typeID: String)
        case duplicateTypeID(String)
        case duplicateTypeName(String)
        case duplicateStatePropertyName(stateID: String, propertyName: String)
        case duplicateEventPropertyName(eventID: String, propertyName: String)
        case duplicateTypePropertyName(typeID: String, propertyName: String)
        case duplicateTypeCaseName(typeID: String, caseName: String)
        case emptyTypeCaseName(typeID: String, caseID: String)
        case unknownTypeDefaultCase(typeID: String, caseID: String)
        case unknownPropertyTypeReference(ownerID: String, propertyID: String, typeID: String)
        case incompatiblePropertyDefaultValue(ownerID: String, propertyID: String)
        case recursiveTypeReference(typeID: String)
        case unknownInitialState(String)
        case unknownTransitionSourceState(transitionID: String, stateID: String)
        case unknownTransitionTargetState(transitionID: String, stateID: String)
        case unknownTransitionEvent(transitionID: String, eventID: String)
        case duplicateTransitionTargetPropertyAssignment(transitionID: String, propertyID: String)
        case unknownTransitionTargetProperty(transitionID: String, stateID: String, propertyID: String)
        case unknownTransitionSourceProperty(transitionID: String, stateID: String, propertyID: String)
        case unknownTransitionEventProperty(transitionID: String, eventID: String, propertyID: String)
        case unknownTransitionTargetField(transitionID: String, targetPropertyID: String, fieldID: String)
        case duplicateTransitionTargetFieldAssignment(transitionID: String, targetPropertyID: String, fieldID: String)
        case unknownTransitionEnumCase(transitionID: String, targetPropertyID: String, caseID: String)
        case incompatibleTransitionTargetPropertyAssignment(transitionID: String, targetPropertyID: String)
    }

    private func validatePropertyDefinitions(
        _ properties: [PropertyDefinition],
        ownerID: String,
        knownTypeIDs: Set<String>,
        errors: inout [ValidationError]
    ) {
        for property in properties {
            if let referencedTypeID = property.type.referencedTypeID,
               !knownTypeIDs.contains(referencedTypeID) {
                errors.append(
                    .unknownPropertyTypeReference(
                        ownerID: ownerID,
                        propertyID: property.id,
                        typeID: referencedTypeID
                    )
                )
            }

            if let defaultValue = property.defaultValue,
               let propertySchema = schema(for: property),
               !isValid(
                propertyDefaultValue: defaultValue,
                expectedType: property.type,
                expectedSchema: propertySchema
               ) {
                errors.append(
                    .incompatiblePropertyDefaultValue(
                        ownerID: ownerID,
                        propertyID: property.id
                    )
                )
            }
        }
    }

    private func isValid(
        propertyDefaultValue: PropertyDefaultValue,
        expectedType: PropertyType,
        expectedSchema: ResolvedPropertySchema
    ) -> Bool {
        switch propertyDefaultValue {
        case .string, .integer, .double, .boolean:
            return expectedSchema == .primitive(type: propertyDefaultValue.primitiveType ?? .string)

        case .structValue(let fields):
            guard case .structType(let targetFields) = expectedSchema else {
                return false
            }

            let fieldIDs = fields.map(\.fieldID)
            guard Set(fieldIDs).count == fieldIDs.count else {
                return false
            }

            let targetFieldMap = targetFields.reduce(into: [String: ResolvedPropertyField]()) { partialResult, field in
                partialResult[field.id] = field
            }

            guard fields.allSatisfy({ fieldAssignment in
                guard let targetField = targetFieldMap[fieldAssignment.fieldID] else {
                    return false
                }

                return isValid(
                    propertyDefaultValue: fieldAssignment.value,
                    expectedType: targetField.type,
                    expectedSchema: targetField.schema
                )
            }) else {
                return false
            }

            let assignedFieldIDs = Set(fieldIDs)
            return targetFields.allSatisfy { field in
                field.isOptional || assignedFieldIDs.contains(field.id)
            }

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = expectedSchema,
                  let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                return false
            }

            switch (resolvedCase.payloadSchema, payload) {
            case (nil, nil):
                return true
            case (nil, .some), (.some, nil):
                return false
            case let (.some(payloadSchema), .some(payloadValue)):
                guard let payloadType = resolvedCase.payloadType else {
                    return false
                }

                return isValid(
                    propertyDefaultValue: payloadValue,
                    expectedType: payloadType,
                    expectedSchema: payloadSchema
                )
            }
        }
    }

    private func validateTypeCycle(
        startingAt typeID: String,
        visiting: inout Set<String>,
        visited: inout Set<String>,
        errors: inout [ValidationError]
    ) {
        guard !visited.contains(typeID) else {
            return
        }

        if visiting.contains(typeID) {
            errors.append(.recursiveTypeReference(typeID: typeID))
            return
        }

        guard let typeDefinition = payloadTypeDefinition(id: typeID) else {
            return
        }

        visiting.insert(typeID)

        let referencedTypeIDs: [String]
        switch typeDefinition.kind {
        case .structType(let fields):
            referencedTypeIDs = fields.compactMap(\.type.referencedTypeID)
        case .enumType(let cases, _):
            referencedTypeIDs = cases.compactMap { payloadCase in
                payloadCase.payloadType?.referencedTypeID
            }
        }

        for referencedTypeID in referencedTypeIDs {
            validateTypeCycle(
                startingAt: referencedTypeID,
                visiting: &visiting,
                visited: &visited,
                errors: &errors
            )
        }

        visiting.remove(typeID)
        visited.insert(typeID)
    }

    private func validateTransitionValueSource(
        _ valueSource: TransitionTargetStateValueSource,
        expectedType: PropertyType,
        expectedSchema: ResolvedPropertySchema,
        transitionID: String,
        targetPropertyID: String,
        sourceStateID: String,
        eventID: String,
        sourceProperties: [PropertyDefinition],
        eventProperties: [PropertyDefinition],
        errors: inout [ValidationError]
    ) {
        switch valueSource {
        case .targetDefault, .custom:
            break

        case .sourceStateProperty(let reference):
            guard let resolvedType = propertyType(
                for: reference,
                in: sourceProperties
            ),
                  let resolvedSchema = schema(
                for: reference,
                in: sourceProperties
            ) else {
                errors.append(
                    .unknownTransitionSourceProperty(
                        transitionID: transitionID,
                        stateID: sourceStateID,
                        propertyID: reference.propertyID
                    )
                )
                return
            }

            if resolvedType != expectedType || resolvedSchema != expectedSchema {
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
            }

        case .eventProperty(let reference):
            guard let resolvedType = propertyType(
                for: reference,
                in: eventProperties
            ),
                  let resolvedSchema = schema(
                for: reference,
                in: eventProperties
            ) else {
                errors.append(
                    .unknownTransitionEventProperty(
                        transitionID: transitionID,
                        eventID: eventID,
                        propertyID: reference.propertyID
                    )
                )
                return
            }

            if resolvedType != expectedType || resolvedSchema != expectedSchema {
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
            }

        case .literal(let literalValue):
            if expectedSchema != .primitive(type: literalValue.type) {
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
            }

        case .fieldMap(let fields):
            guard case .structType(let targetFields) = expectedSchema else {
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
                return
            }

            let fieldIDs = fields.map(\.fieldID)
            for duplicateFieldID in Set(fieldIDs.filter { fieldID in
                fieldIDs.filter { $0 == fieldID }.count > 1
            }) {
                errors.append(
                    .duplicateTransitionTargetFieldAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID,
                        fieldID: duplicateFieldID
                    )
                )
            }

            let targetFieldMap = targetFields.reduce(into: [String: ResolvedPropertyField]()) { partialResult, field in
                partialResult[field.id] = field
            }

            for fieldAssignment in fields {
                guard let targetField = targetFieldMap[fieldAssignment.fieldID] else {
                    errors.append(
                        .unknownTransitionTargetField(
                            transitionID: transitionID,
                            targetPropertyID: targetPropertyID,
                            fieldID: fieldAssignment.fieldID
                        )
                    )
                    continue
                }

                validateTransitionValueSource(
                    fieldAssignment.valueSource,
                    expectedType: targetField.type,
                    expectedSchema: targetField.schema,
                    transitionID: transitionID,
                    targetPropertyID: targetPropertyID,
                    sourceStateID: sourceStateID,
                    eventID: eventID,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    errors: &errors
                )
            }

        case .enumCase(let caseID, let payload):
            guard case .enumType(let cases, _) = expectedSchema else {
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
                return
            }

            guard let resolvedCase = cases.first(where: { $0.id == caseID }) else {
                errors.append(
                    .unknownTransitionEnumCase(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID,
                        caseID: caseID
                    )
                )
                return
            }

            switch (resolvedCase.payloadSchema, payload) {
            case (nil, nil), (.some, nil):
                break
            case (nil, .some):
                errors.append(
                    .incompatibleTransitionTargetPropertyAssignment(
                        transitionID: transitionID,
                        targetPropertyID: targetPropertyID
                    )
                )
            case let (.some(payloadSchema), .some(payloadValueSource)):
                validateTransitionValueSource(
                    payloadValueSource,
                    expectedType: resolvedCase.payloadType ?? .string,
                    expectedSchema: payloadSchema,
                    transitionID: transitionID,
                    targetPropertyID: targetPropertyID,
                    sourceStateID: sourceStateID,
                    eventID: eventID,
                    sourceProperties: sourceProperties,
                    eventProperties: eventProperties,
                    errors: &errors
                )
            }
        }
    }
}
