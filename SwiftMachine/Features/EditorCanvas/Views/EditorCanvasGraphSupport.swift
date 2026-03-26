//
//  EditorCanvasGraphSupport.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import SwiftUI

struct ConnectionSnapTarget: Equatable {
    let stateID: String
    let anchor: StateMachineEditorPoint
}

enum GraphCanvasMetrics {
    static let workspaceWidth: CGFloat = 2_400
    static let workspaceHeight: CGFloat = 1_600
    static let defaultZoomScale: CGFloat = 1
    static let minimumZoomScale: CGFloat = 0.5
    static let maximumZoomScale: CGFloat = 2.5
    static let nodeWidth = CGFloat(StateMachineEditorDocument.stateNodeSize.width)
    static let nodeHeight = CGFloat(StateMachineEditorDocument.stateNodeSize.height)
    static let transitionCardWidth: CGFloat = 240
    static let transitionCardHeight: CGFloat = 124
    static let nodePadding: CGFloat = 18
    static let connectionHandleSize: CGFloat = 22
    static let connectionSnapDistance: CGFloat = 44
    static let initialStateArrowLength: CGFloat = 56
    static let promptWidth: CGFloat = 420
    static let promptHeight: CGFloat = 680
    static let edgeHitWidth: CGFloat = 20
}

extension EditorCanvasPresentationState {
    func snapTarget(
        for location: StateMachineEditorPoint,
        excluding sourceStateID: String
    ) -> ConnectionSnapTarget? {
        let snapDistance = Double(GraphCanvasMetrics.connectionSnapDistance)

        return document.definition.states
            .filter { $0.id != sourceStateID }
            .map { state in
                let anchor = document.connectionAnchor(for: state.id)
                let distance = hypot(anchor.x - location.x, anchor.y - location.y)
                return (stateID: state.id, anchor: anchor, distance: distance)
            }
            .filter { $0.distance <= snapDistance }
            .min(by: { $0.distance < $1.distance })
            .map { ConnectionSnapTarget(stateID: $0.stateID, anchor: $0.anchor) }
    }
}

extension StateMachineEditorPoint {
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

extension StateMachineEditorRect {
    var cgRect: CGRect {
        CGRect(
            x: origin.x,
            y: origin.y,
            width: size.width,
            height: size.height
        )
    }
}

extension StateMachineEditorDocument {
    func connectionAnchor(for stateID: String) -> StateMachineEditorPoint {
        let position = position(for: stateID)
        let handleRadius = Double(GraphCanvasMetrics.connectionHandleSize / 2)
        let handlePadding = Double(GraphCanvasMetrics.nodePadding)

        return position.translatingBy(
            dx: Double(GraphCanvasMetrics.nodeWidth) - handlePadding - handleRadius,
            dy: handlePadding + handleRadius
        )
    }
}
