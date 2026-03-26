//
//  TransitionPathGeometry.swift
//  SwiftMachine
//
//  Created by Codex on 26/03/2026.
//

import SwiftUI

struct ConnectionDraftGeometry {
    let path: Path
    let arrowPath: Path

    init(start: CGPoint, end: CGPoint) {
        let horizontalDistance = abs(end.x - start.x)
        let controlOffset = max(70, horizontalDistance * 0.35)
        var control1 = CGPoint(
            x: start.x + controlOffset,
            y: start.y
        )
        var control2 = CGPoint(
            x: end.x - controlOffset,
            y: end.y
        )

        if horizontalDistance < 120 {
            control1.y -= 70
            control2.y -= 70
        }

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
        let arrowAngle = atan2(end.y - control2.y, end.x - control2.x)

        self.path = path
        self.arrowPath = TransitionPathGeometry.makeArrowPath(tip: end, angle: arrowAngle)
    }
}

struct TransitionPathGeometry {
    let path: Path
    let hitPath: Path
    let arrowPath: Path
    let arrowTip: CGPoint
    let labelPosition: CGPoint

    init(sourceFrame: CGRect, transitionAnchor: CGPoint, targetFrame: CGRect) {
        self = Self.makeRoutedPath(
            sourceFrame: sourceFrame,
            transitionAnchor: transitionAnchor,
            targetFrame: targetFrame
        )
    }

    init(sourceFrame: CGRect, targetFrame: CGRect) {
        if sourceFrame == targetFrame {
            self = Self.makeSelfLoop(frame: sourceFrame)
        } else {
            self = Self.makeStandardPath(sourceFrame: sourceFrame, targetFrame: targetFrame)
        }
    }

    private init(
        path: Path,
        hitPath: Path,
        arrowPath: Path,
        arrowTip: CGPoint,
        labelPosition: CGPoint
    ) {
        self.path = path
        self.hitPath = hitPath
        self.arrowPath = arrowPath
        self.arrowTip = arrowTip
        self.labelPosition = labelPosition
    }

    private static func makeRoutedPath(
        sourceFrame: CGRect,
        transitionAnchor: CGPoint,
        targetFrame: CGRect
    ) -> TransitionPathGeometry {
        if sourceFrame == targetFrame {
            return makeRoutedSelfLoop(
                frame: sourceFrame,
                transitionAnchor: transitionAnchor
            )
        }

        let start = point(on: sourceFrame, toward: transitionAnchor)
        let end = point(on: targetFrame, toward: transitionAnchor)
        let firstControls = curveControls(start: start, end: transitionAnchor)
        let secondControls = curveControls(start: transitionAnchor, end: end)

        let path = Path { path in
            path.move(to: start)
            path.addCurve(
                to: transitionAnchor,
                control1: firstControls.control1,
                control2: firstControls.control2
            )
            path.move(to: transitionAnchor)
            path.addCurve(
                to: end,
                control1: secondControls.control1,
                control2: secondControls.control2
            )
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let arrowAngle = atan2(
            end.y - secondControls.control2.y,
            end.x - secondControls.control2.x
        )
        let arrowPath = makeArrowPath(tip: end, angle: arrowAngle)

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: end,
            labelPosition: transitionAnchor
        )
    }

    private static func makeRoutedSelfLoop(
        frame: CGRect,
        transitionAnchor: CGPoint
    ) -> TransitionPathGeometry {
        let attachmentPoints = selfLoopAttachmentPoints(
            on: frame,
            toward: transitionAnchor
        )
        let firstControls = curveControls(
            start: attachmentPoints.start,
            end: transitionAnchor
        )
        let secondControls = curveControls(
            start: transitionAnchor,
            end: attachmentPoints.end
        )

        let path = Path { path in
            path.move(to: attachmentPoints.start)
            path.addCurve(
                to: transitionAnchor,
                control1: firstControls.control1,
                control2: firstControls.control2
            )
            path.addCurve(
                to: attachmentPoints.end,
                control1: secondControls.control1,
                control2: secondControls.control2
            )
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let arrowPlacement = visibleArrowPlacement(
            start: transitionAnchor,
            control1: secondControls.control1,
            control2: secondControls.control2,
            end: attachmentPoints.end,
            avoiding: frame
        )
        let arrowPath = makeArrowPath(
            tip: arrowPlacement.tip,
            angle: arrowPlacement.angle
        )

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: arrowPlacement.tip,
            labelPosition: transitionAnchor
        )
    }

    private static func makeStandardPath(
        sourceFrame: CGRect,
        targetFrame: CGRect
    ) -> TransitionPathGeometry {
        let isForward = sourceFrame.midX <= targetFrame.midX
        let start = CGPoint(
            x: isForward ? sourceFrame.maxX : sourceFrame.minX,
            y: sourceFrame.midY
        )
        let end = CGPoint(
            x: isForward ? targetFrame.minX : targetFrame.maxX,
            y: targetFrame.midY
        )
        let horizontalDistance = abs(end.x - start.x)
        let controlOffset = max(80, horizontalDistance * 0.35)
        var control1 = CGPoint(
            x: start.x + (isForward ? controlOffset : -controlOffset),
            y: start.y
        )
        var control2 = CGPoint(
            x: end.x - (isForward ? controlOffset : -controlOffset),
            y: end.y
        )

        if horizontalDistance < 120 {
            control1.y -= 90
            control2.y -= 90
        }

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let labelPosition = cubicPoint(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: 0.5
        )
        let arrowAngle = atan2(end.y - control2.y, end.x - control2.x)
        let arrowPath = makeArrowPath(tip: end, angle: arrowAngle)

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: end,
            labelPosition: labelPosition
        )
    }

    private static func makeSelfLoop(frame: CGRect) -> TransitionPathGeometry {
        let start = CGPoint(x: frame.midX + 36, y: frame.minY + 10)
        let end = CGPoint(x: frame.midX - 36, y: frame.minY + 10)
        let control1 = CGPoint(x: frame.maxX + 70, y: frame.minY - 80)
        let control2 = CGPoint(x: frame.minX - 70, y: frame.minY - 80)

        let path = Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        let hitPath = path.strokedPath(
            StrokeStyle(lineWidth: GraphCanvasMetrics.edgeHitWidth, lineCap: .round, lineJoin: .round)
        )
        let labelPosition = CGPoint(x: frame.midX, y: frame.minY - 78)
        let arrowPlacement = visibleArrowPlacement(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            avoiding: frame
        )
        let arrowPath = makeArrowPath(tip: arrowPlacement.tip, angle: arrowPlacement.angle)

        return TransitionPathGeometry(
            path: path,
            hitPath: hitPath,
            arrowPath: arrowPath,
            arrowTip: arrowPlacement.tip,
            labelPosition: labelPosition
        )
    }

    private static func selfLoopAttachmentPoints(
        on frame: CGRect,
        toward anchor: CGPoint
    ) -> (start: CGPoint, end: CGPoint) {
        let horizontalInset = min(max(frame.width * 0.18, 28), 40)
        let verticalInset = min(max(frame.height * 0.22, 24), 34)
        let edgeInset: CGFloat = 10

        switch selfLoopSide(for: frame, toward: anchor) {
        case .top:
            return (
                start: CGPoint(x: frame.midX + horizontalInset, y: frame.minY + edgeInset),
                end: CGPoint(x: frame.midX - horizontalInset, y: frame.minY + edgeInset)
            )
        case .right:
            return (
                start: CGPoint(x: frame.maxX - edgeInset, y: frame.midY - verticalInset),
                end: CGPoint(x: frame.maxX - edgeInset, y: frame.midY + verticalInset)
            )
        case .bottom:
            return (
                start: CGPoint(x: frame.midX - horizontalInset, y: frame.maxY - edgeInset),
                end: CGPoint(x: frame.midX + horizontalInset, y: frame.maxY - edgeInset)
            )
        case .left:
            return (
                start: CGPoint(x: frame.minX + edgeInset, y: frame.midY + verticalInset),
                end: CGPoint(x: frame.minX + edgeInset, y: frame.midY - verticalInset)
            )
        }
    }

    private static func selfLoopSide(
        for frame: CGRect,
        toward anchor: CGPoint
    ) -> SelfLoopSide {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let normalizedX = (anchor.x - center.x) / max(frame.width / 2, CGFloat.leastNonzeroMagnitude)
        let normalizedY = (anchor.y - center.y) / max(frame.height / 2, CGFloat.leastNonzeroMagnitude)

        if abs(normalizedY) >= abs(normalizedX) {
            return normalizedY <= 0 ? .top : .bottom
        }

        return normalizedX >= 0 ? .right : .left
    }

    private static func point(on frame: CGRect, toward target: CGPoint) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let deltaX = target.x - center.x
        let deltaY = target.y - center.y

        guard deltaX != 0 || deltaY != 0 else {
            return center
        }

        let halfWidth = frame.width / 2
        let halfHeight = frame.height / 2
        let scale = max(abs(deltaX) / halfWidth, abs(deltaY) / halfHeight)

        return CGPoint(
            x: center.x + (deltaX / scale),
            y: center.y + (deltaY / scale)
        )
    }

    private static func curveControls(
        start: CGPoint,
        end: CGPoint
    ) -> (control1: CGPoint, control2: CGPoint) {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y

        if abs(deltaX) >= abs(deltaY) {
            let horizontalOffset = max(54, abs(deltaX) * 0.35)
            let signedOffset = deltaX >= 0 ? horizontalOffset : -horizontalOffset

            return (
                control1: CGPoint(x: start.x + signedOffset, y: start.y),
                control2: CGPoint(x: end.x - signedOffset, y: end.y)
            )
        }

        let verticalOffset = max(54, abs(deltaY) * 0.35)
        let signedOffset = deltaY >= 0 ? verticalOffset : -verticalOffset

        return (
            control1: CGPoint(x: start.x, y: start.y + signedOffset),
            control2: CGPoint(x: end.x, y: end.y - signedOffset)
        )
    }

    private static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let x = (oneMinusT * oneMinusT * oneMinusT * start.x) +
            (3 * oneMinusT * oneMinusT * t * control1.x) +
            (3 * oneMinusT * t * t * control2.x) +
            (t * t * t * end.x)
        let y = (oneMinusT * oneMinusT * oneMinusT * start.y) +
            (3 * oneMinusT * oneMinusT * t * control1.y) +
            (3 * oneMinusT * t * t * control2.y) +
            (t * t * t * end.y)

        return CGPoint(x: x, y: y)
    }

    private static func cubicTangent(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGVector {
        let oneMinusT = 1 - t
        let dx = (3 * oneMinusT * oneMinusT * (control1.x - start.x)) +
            (6 * oneMinusT * t * (control2.x - control1.x)) +
            (3 * t * t * (end.x - control2.x))
        let dy = (3 * oneMinusT * oneMinusT * (control1.y - start.y)) +
            (6 * oneMinusT * t * (control2.y - control1.y)) +
            (3 * t * t * (end.y - control2.y))

        return CGVector(dx: dx, dy: dy)
    }

    private static func visibleArrowPlacement(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        avoiding frame: CGRect
    ) -> (tip: CGPoint, angle: CGFloat) {
        let clearanceFrame = frame.insetBy(dx: -6, dy: -6)
        let tipT = stride(from: 0.99, through: 0.75, by: -0.01)
            .map { CGFloat($0) }
            .first { t in
                let point = cubicPoint(
                    start: start,
                    control1: control1,
                    control2: control2,
                    end: end,
                    t: t
                )
                return !clearanceFrame.contains(point)
            } ?? 1
        let tip = cubicPoint(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: tipT
        )
        let tangent = cubicTangent(
            start: start,
            control1: control1,
            control2: control2,
            end: end,
            t: tipT
        )
        let angle = atan2(tangent.dy, tangent.dx)

        return (tip: tip, angle: angle)
    }

    static func makeArrowPath(tip: CGPoint, angle: CGFloat) -> Path {
        let arrowLength: CGFloat = 12
        let arrowSpread: CGFloat = .pi / 6
        let point1 = CGPoint(
            x: tip.x - cos(angle - arrowSpread) * arrowLength,
            y: tip.y - sin(angle - arrowSpread) * arrowLength
        )
        let point2 = CGPoint(
            x: tip.x - cos(angle + arrowSpread) * arrowLength,
            y: tip.y - sin(angle + arrowSpread) * arrowLength
        )

        return Path { path in
            path.move(to: tip)
            path.addLine(to: point1)
            path.addLine(to: point2)
            path.closeSubpath()
        }
    }
}

private enum SelfLoopSide {
    case top
    case right
    case bottom
    case left
}
