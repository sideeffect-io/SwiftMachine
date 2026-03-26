//
//  PropertyDefaultValue+Signature.swift
//  SwiftMachine
//
//  Created by Codex on 20/03/2026.
//

import Foundation

extension PropertyDefaultValue {
    nonisolated var signatureFragment: String {
        switch self {
        case .string(let value):
            return "string:\(value)"
        case .integer(let value):
            return "integer:\(value)"
        case .double(let value):
            return "double:\(value)"
        case .boolean(let value):
            return "boolean:\(value)"
        case .structValue(let fields):
            let fragments = fields.map { field in
                "\(field.fieldID)=\(field.value.signatureFragment)"
            }
            .joined(separator: ",")

            return "struct:{\(fragments)}"
        case .enumCase(let caseID, let payload):
            let payloadFragment = payload?.signatureFragment ?? "nil"
            return "enum:\(caseID):\(payloadFragment)"
        }
    }
}
