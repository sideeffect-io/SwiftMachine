//
//  TransitionPathGeometryTests.swift
//  SwiftMachineTests
//
//  Created by Codex on 16/03/2026.
//

import CoreGraphics
import Testing
@testable import SwiftMachine

struct TransitionPathGeometryTests {

    @Test("Self-loop arrow tip stays outside the node frame")
    func selfLoopArrowTipRemainsVisible() {
        let frame = CGRect(x: 360, y: 240, width: 220, height: 120)
        let geometry = TransitionPathGeometry(
            sourceFrame: frame,
            targetFrame: frame
        )

        #expect(geometry.arrowTip.y < frame.minY)
        #expect(geometry.arrowTip.x < frame.midX)
    }

    @Test("Graph labels include the guard name when a transition is guarded")
    func graphLabelIncludesGuardName() {
        let transition = TransitionDefinition(
            id: "guarded",
            sourceStateID: "idle",
            eventID: "begin",
            targetStateID: "loading",
            guard: GuardReference(name: "canBegin")
        )

        let label = transition.graphLabel(eventName: "Begin")

        #expect(label == TransitionGraphLabel(
            eventName: "Begin",
            guardName: "canBegin",
            effectNames: []
        ))
    }

    @Test("Graph labels omit the guard when the transition is unguarded")
    func graphLabelOmitsMissingGuard() {
        let transition = TransitionDefinition(
            id: "unguarded",
            sourceStateID: "idle",
            eventID: "begin",
            targetStateID: "loading"
        )

        let label = transition.graphLabel(eventName: "Begin")

        #expect(label == TransitionGraphLabel(
            eventName: "Begin",
            guardName: nil,
            effectNames: []
        ))
    }

    @Test("Graph labels include normalized effect names")
    func graphLabelIncludesEffectNames() {
        let transition = TransitionDefinition(
            id: "effects",
            sourceStateID: "idle",
            eventID: "begin",
            targetStateID: "loading",
            effects: [
                EffectReference(name: " start "),
                EffectReference(name: " "),
                EffectReference(name: "notifyObservers")
            ]
        )

        let label = transition.graphLabel(eventName: "Begin")

        #expect(label == TransitionGraphLabel(
            eventName: "Begin",
            guardName: nil,
            effectNames: [
                "start",
                "notifyObservers"
            ]
        ))
    }
}
