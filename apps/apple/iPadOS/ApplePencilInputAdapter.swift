import Foundation

#if canImport(UIKit)
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Extracts 240Hz coalesced touches and low-latency predicted touches from UIKit
/// (iPadOS & iPhone Duo) for direct forwarding into `manga-core`.
@MainActor
public enum ApplePencilInputAdapter {
    public static func extractSamples(
        touch: UITouch,
        event: UIEvent?,
        in view: UIView
    ) -> [NativeStrokeSample] {
        var samples: [NativeStrokeSample] = []

        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        samples.reserveCapacity(coalesced.count + 4)

        for item in coalesced {
            samples.append(makeSample(from: item, in: view, isPredicted: false))
        }

        if let predicted = event?.predictedTouches(for: touch) {
            for item in predicted {
                samples.append(makeSample(from: item, in: view, isPredicted: true))
            }
        }

        return samples
    }

    private static func makeSample(
        from touch: UITouch,
        in view: UIView,
        isPredicted: Bool
    ) -> NativeStrokeSample {
        let loc = touch.preciseLocation(in: view)
        let normalizedForce: Float = touch.maximumPossibleForce > 0
            ? Float(touch.force / touch.maximumPossibleForce)
            : 0.5

        let roll: Float
        if #available(iOS 17.5, *) {
            roll = Float(touch.rollAngle)
        } else {
            roll = 0.0
        }

        return NativeStrokeSample(
            x: Float(loc.x),
            y: Float(loc.y),
            pressure: min(max(normalizedForce, 0.0), 1.0),
            altitude: Float(touch.altitudeAngle),
            azimuth: Float(touch.azimuthAngle(in: view)),
            rollAngle: roll,
            timestampMs: touch.timestamp * 1000.0,
            isPredicted: isPredicted
        )
    }
}

#if canImport(SwiftUI)
/// Native 240Hz UIKit + Apple Pencil Pro touch surface for physical **iPad Pro 13-inch (M5)**:
/// - Hardware `force` (pressure), `altitudeAngle` (tilt), and `rollAngle` (barrel roll).
/// - `UIPencilInteraction`: Double-Tap (Brush ↔ Eraser) & Apple Pencil Pro Squeeze (toggle Drawer).
/// - Built-in Palm Rejection + `Apple Pencil Only` mode (finger pans canvas while Pencil draws).
/// - Native 2-finger tap Undo & 3-finger tap Redo gestures.
public struct ApplePencilCanvasOverlayView: UIViewRepresentable {
    public let controller: StudioWorkspaceController
    public let presetHardness: Float
    public let onStatusUpdate: (String) -> Void

    public init(
        controller: StudioWorkspaceController,
        presetHardness: Float,
        onStatusUpdate: @escaping (String) -> Void
    ) {
        self.controller = controller
        self.presetHardness = presetHardness
        self.onStatusUpdate = onStatusUpdate
    }

    public func makeUIView(context: Context) -> ApplePencilTouchCanvasUIView {
        let view = ApplePencilTouchCanvasUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.controller = controller
        view.presetHardness = presetHardness
        view.onStatusUpdate = onStatusUpdate
        return view
    }

    public func updateUIView(_ uiView: ApplePencilTouchCanvasUIView, context: Context) {
        uiView.controller = controller
        uiView.presetHardness = presetHardness
        uiView.onStatusUpdate = onStatusUpdate
    }
}

@MainActor
public final class ApplePencilTouchCanvasUIView: UIView, UIPencilInteractionDelegate {
    public weak var controller: StudioWorkspaceController?
    public var presetHardness: Float = 0.90
    public var onStatusUpdate: ((String) -> Void)?

    private var activeTouch: UITouch?
    private var lastCanvasPt: CGPoint?
    private var anchorCanvasPt: CGPoint?
    private var stabilizedPt: CGPoint?
    private var dragStartCanvasPt: CGPoint?
    private var dragStartNormPt: CGPoint?
    private var lassoCanvasPts: [CGPoint] = []
    private var lassoNormPts: [CGPoint] = []
    private var fingerPanPrevLocation: CGPoint?
    private var lastToolBeforeEraser: S2DrawingToolKind = .brush

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupPencilAndTouchGestures()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPencilAndTouchGestures()
    }

    private func setupPencilAndTouchGestures() {
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)

        let twoFingerUndo = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTapUndo))
        twoFingerUndo.numberOfTouchesRequired = 2
        twoFingerUndo.delaysTouchesBegan = false
        twoFingerUndo.cancelsTouchesInView = false
        addGestureRecognizer(twoFingerUndo)

        let threeFingerRedo = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTapRedo))
        threeFingerRedo.numberOfTouchesRequired = 3
        threeFingerRedo.delaysTouchesBegan = false
        threeFingerRedo.cancelsTouchesInView = false
        addGestureRecognizer(threeFingerRedo)
    }

    @objc private func handleTwoFingerTapUndo() {
        guard let ctrl = controller else { return }
        ctrl.performUndoStroke()
        onStatusUpdate?("2-Finger Tap → Undo")
    }

    @objc private func handleThreeFingerTapRedo() {
        guard let ctrl = controller else { return }
        ctrl.performRedoStroke()
        onStatusUpdate?("3-Finger Tap → Redo")
    }

    // MARK: - Apple Pencil Pro Hardware Interactions

    @available(iOS 17.5, *)
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        guard let ctrl = controller else { return }
        if ctrl.s2Tool == .eraser {
            ctrl.selectTool(lastToolBeforeEraser)
            onStatusUpdate?("Apple Pencil Double-Tap → \(lastToolBeforeEraser.displayName)")
        } else {
            lastToolBeforeEraser = ctrl.s2Tool
            ctrl.selectTool(.eraser)
            onStatusUpdate?("Apple Pencil Double-Tap → Eraser")
        }
    }

    @available(iOS 17.5, *)
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended, let ctrl = controller else { return }
        ctrl.s2ShowLayerDrawer.toggle()
        onStatusUpdate?(ctrl.s2ShowLayerDrawer ? "Pencil Pro Squeeze → Layers Drawer" : "Pencil Pro Squeeze → Brushes")
    }

    // MARK: - 240Hz Coalesced Touch & Palm-Rejection Drawing

    private func mapToCanvas(_ loc: CGPoint) -> (canvas: CGPoint, norm: CGPoint) {
        let w = max(1.0, bounds.width)
        let h = max(1.0, bounds.height)
        let nx = min(max(loc.x / w, 0.0), 1.0)
        let ny = min(max(loc.y / h, 0.0), 1.0)
        let cw = CGFloat(controller?.s2CanvasPixelWidth ?? 800)
        let ch = CGFloat(controller?.s2CanvasPixelHeight ?? 1132)
        return (CGPoint(x: nx * cw, y: ny * ch), CGPoint(x: nx, y: ny))
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let ctrl = controller else { return }
        // Prefer Apple Pencil over finger touches when both contact simultaneously
        let candidate = touches.first(where: { $0.type == .pencil }) ?? touches.first
        guard let touch = candidate else { return }

        // Palm rejection: large non-pencil contacts (> 28pt radius) are ignored
        if touch.type != .pencil && touch.majorRadius > 28.0 {
            return
        }

        // Apple Pencil Only mode: finger pans canvas smoothly while Apple Pencil draws!
        if ctrl.s2ApplePencilOnlyDraw && touch.type != .pencil {
            fingerPanPrevLocation = touch.location(in: superview)
            return
        }

        activeTouch = touch
        let mapped = mapToCanvas(touch.preciseLocation(in: self))

        switch ctrl.s2Tool {
        case .eyedropper:
            if let picked = ctrl.sampleEyedropper(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y)) {
                onStatusUpdate?("Eyedropper: \(picked.hexString)")
            }
        case .bucket, .magicWand, .textBubble, .transform:
            dragStartCanvasPt = mapped.canvas
            dragStartNormPt = mapped.norm
        case .rectSelect, .panelKnife:
            dragStartCanvasPt = mapped.canvas
            dragStartNormPt = mapped.norm
        case .lasso:
            lassoCanvasPts = [mapped.canvas]
            lassoNormPts = [mapped.norm]
        case .brush, .eraser, .smudge, .blur:
            if ctrl.s2Tool == .brush && ctrl.s2ShapeAssist != .freehand {
                dragStartCanvasPt = mapped.canvas
                dragStartNormPt = mapped.norm
                return
            }
            if let layer = ctrl.selectedCelLayer, !layer.visible {
                onStatusUpdate?("Layer '\(layer.name)' is hidden.")
                return
            }
            ctrl.beginRasterUndoCheckpoint()
            anchorCanvasPt = mapped.canvas
            lastCanvasPt = mapped.canvas
            stabilizedPt = mapped.canvas
            processCoalescedStrokeSamples(touch: touch, event: event, ctrl: ctrl)
        default:
            break
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let ctrl = controller else { return }

        if let prevPan = fingerPanPrevLocation,
           let finger = touches.first(where: { $0.type != .pencil })
        {
            let cur = finger.location(in: superview)
            ctrl.s2PanOffset = CGSize(
                width: ctrl.s2PanOffset.width + (cur.x - prevPan.x),
                height: ctrl.s2PanOffset.height + (cur.y - prevPan.y)
            )
            fingerPanPrevLocation = cur
            return
        }

        guard let touch = activeTouch, touches.contains(touch) else { return }
        let mapped = mapToCanvas(touch.preciseLocation(in: self))

        switch ctrl.s2Tool {
        case .eyedropper:
            if let picked = ctrl.sampleEyedropper(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y)) {
                onStatusUpdate?("Eyedropper: \(picked.hexString)")
            }
        case .lasso:
            lassoCanvasPts.append(mapped.canvas)
            lassoNormPts.append(mapped.norm)
        case .brush, .eraser, .smudge, .blur:
            if ctrl.s2Tool == .brush && ctrl.s2ShapeAssist != .freehand {
                return
            }
            processCoalescedStrokeSamples(touch: touch, event: event, ctrl: ctrl)
        default:
            break
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fingerPanPrevLocation = nil
        guard let ctrl = controller, let touch = activeTouch, touches.contains(touch) else { return }
        let mapped = mapToCanvas(touch.preciseLocation(in: self))

        switch ctrl.s2Tool {
        case .bucket:
            let filled = ctrl.applyBucketFill(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y))
            onStatusUpdate?("Close-Gap Bucket filled \(filled) px")
        case .magicWand:
            let count = ctrl.applyMagicWandSelection(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y))
            onStatusUpdate?("Magic Wand selected \(count) px")
        case .textBubble:
            ctrl.addSpeechBubble(normX: Double(mapped.norm.x), normY: Double(mapped.norm.y))
            onStatusUpdate?(ctrl.lastStatusBanner)
        case .panelKnife:
            if let start = dragStartCanvasPt {
                let count = ctrl.slicePanelFrame(from: start, to: mapped.canvas, gutterPx: 14.0)
                onStatusUpdate?("Panel Knife sliced frame (\(count) panels)")
            }
        case .rectSelect:
            if let sNorm = dragStartNormPt, let sCanvas = dragStartCanvasPt {
                let normRect = CGRect(
                    x: min(sNorm.x, mapped.norm.x),
                    y: min(sNorm.y, mapped.norm.y),
                    width: abs(mapped.norm.x - sNorm.x),
                    height: abs(mapped.norm.y - sNorm.y)
                )
                let canvasRect = CGRect(
                    x: min(sCanvas.x, mapped.canvas.x),
                    y: min(sCanvas.y, mapped.canvas.y),
                    width: abs(mapped.canvas.x - sCanvas.x),
                    height: abs(mapped.canvas.y - sCanvas.y)
                )
                let count = ctrl.setMarqueeSelection(canvasRect: canvasRect, normRect: normRect)
                onStatusUpdate?("Marquee selected \(count) px")
            }
        case .lasso:
            if lassoCanvasPts.count >= 3 {
                let count = ctrl.setLassoSelection(canvasPoints: lassoCanvasPts, normPoints: lassoNormPts)
                onStatusUpdate?("Lasso selected \(count) px")
            }
            lassoCanvasPts.removeAll()
            lassoNormPts.removeAll()
        case .brush, .eraser, .smudge, .blur:
            if ctrl.s2Tool == .brush && ctrl.s2ShapeAssist != .freehand, let start = dragStartCanvasPt {
                _ = ctrl.drawRasterShape(
                    kind: ctrl.s2ShapeAssist,
                    from: start,
                    to: mapped.canvas,
                    radiusPx: Float(max(1.0, ctrl.s2BrushSize * 0.5)),
                    hardness: presetHardness,
                    opacity: Float(ctrl.s2BrushOpacity)
                )
                onStatusUpdate?(ctrl.lastStatusBanner)
            } else {
                processCoalescedStrokeSamples(touch: touch, event: event, ctrl: ctrl)
                ctrl.refreshCompositeImage()
                ctrl.markDirtyAndScheduleSave()
                let srcLabel = touch.type == .pencil ? "Apple Pencil Pro" : "Touch"
                onStatusUpdate?("Committed \(srcLabel) \(ctrl.s2Tool.displayName) (\(ctrl.s2AllocatedTiles) tiles)")
            }
        default:
            break
        }

        resetTransientStrokeState()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        fingerPanPrevLocation = nil
        resetTransientStrokeState()
    }

    private func resetTransientStrokeState() {
        activeTouch = nil
        lastCanvasPt = nil
        anchorCanvasPt = nil
        stabilizedPt = nil
        dragStartCanvasPt = nil
        dragStartNormPt = nil
    }

    private func processCoalescedStrokeSamples(touch: UITouch, event: UIEvent?, ctrl: StudioWorkspaceController) {
        let samples = ApplePencilInputAdapter.extractSamples(touch: touch, event: event, in: self)
            .filter { !$0.isPredicted }
        guard !samples.isEmpty else { return }

        let rope = CGFloat(ctrl.s2StabilizerPx)
        let baseRadius = Float(max(0.75, ctrl.s2BrushSize * 0.5))
        let isPencil = touch.type == .pencil

        for sample in samples {
            let mapped = mapToCanvas(CGPoint(x: CGFloat(sample.x), y: CGFloat(sample.y)))
            let rawPt = mapped.canvas

            let targetPt: CGPoint
            if let prevStab = stabilizedPt, rope > 0.5 {
                let dx = rawPt.x - prevStab.x
                let dy = rawPt.y - prevStab.y
                let dist = hypot(dx, dy)
                if dist > rope {
                    let pull = (dist - rope) / dist
                    targetPt = CGPoint(x: prevStab.x + dx * pull, y: prevStab.y + dy * pull)
                } else {
                    targetPt = prevStab
                }
            } else {
                targetPt = rawPt
            }
            stabilizedPt = targetPt

            let fromPt = lastCanvasPt ?? targetPt
            let anchorPt = anchorCanvasPt ?? targetPt

            if isPencil {
                _ = ctrl.applyPencilPressureSegment(
                    from: fromPt,
                    to: targetPt,
                    anchor: anchorPt,
                    pressure: sample.pressure,
                    altitude: sample.altitude,
                    baseRadiusPx: baseRadius,
                    hardness: presetHardness,
                    opacity: Float(ctrl.s2BrushOpacity)
                )
            } else {
                _ = ctrl.applyRulerAwareRasterSegment(
                    from: fromPt,
                    to: targetPt,
                    anchor: anchorPt,
                    radiusPx: baseRadius,
                    hardness: presetHardness,
                    opacity: Float(ctrl.s2BrushOpacity)
                )
            }
            lastCanvasPt = targetPt
        }
        ctrl.refreshCompositeImage()
    }
}
#endif
#endif
