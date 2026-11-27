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
/// - Always-on 2-finger drag canvas pan + 2-finger tap Undo & 3-finger tap Redo gestures.
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
public final class ApplePencilTouchCanvasUIView: UIView, UIPencilInteractionDelegate, UIGestureRecognizerDelegate {
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
    private var twoFingerPanBaseOffset: CGSize?
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

        // Two-finger pan gesture so the user can always pan left/right/up/down with two fingers
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        twoFingerPan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        twoFingerPan.delaysTouchesBegan = false
        twoFingerPan.cancelsTouchesInView = true
        twoFingerPan.delegate = self
        addGestureRecognizer(twoFingerPan)

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

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        guard let ctrl = controller else { return }
        let translation = recognizer.translation(in: superview ?? self)
        switch recognizer.state {
        case .began:
            twoFingerPanBaseOffset = ctrl.s2PanOffset
            resetTransientStrokeState()
        case .changed:
            let base = twoFingerPanBaseOffset ?? ctrl.s2PanOffset
            ctrl.s2PanOffset = CGSize(
                width: base.width + translation.x,
                height: base.height + translation.y
            )
        case .ended, .cancelled, .failed:
            twoFingerPanBaseOffset = nil
        default:
            break
        }
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
        // If two or more finger touches are down, treat as multi-touch pan/zoom
        let allTouches = event?.allTouches ?? touches
        if allTouches.count >= 2 && !allTouches.contains(where: { $0.type == .pencil }) {
            resetTransientStrokeState()
            return
        }

        // Prefer Apple Pencil over finger touches when both contact simultaneously
        let candidate = touches.first(where: { $0.type == .pencil }) ?? touches.first
        guard let touch = candidate else { return }

        // Palm rejection: large non-pencil contacts (> 28pt radius) are ignored
        if touch.type != .pencil && touch.majorRadius > 28.0 {
            return
        }

        // Hand Pan tool OR Apple Pencil Only mode (finger pans canvas smoothly while Apple Pencil draws)
        if ctrl.s2Tool == .handPan || (ctrl.s2ApplePencilOnlyDraw && touch.type != .pencil) {
            fingerPanPrevLocation = touch.location(in: superview ?? self)
            activeTouch = touch
            return
        }

        activeTouch = touch
        let mapped = mapToCanvas(touch.preciseLocation(in: self))

        switch ctrl.s2Tool {
        case .eyedropper:
            ctrl.s2EyedropperLoupeNorm = mapped.norm
            if let picked = ctrl.sampleEyedropper(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y)) {
                onStatusUpdate?("吸色成功 Eyedropper: \(picked.hexString) (RGB \(picked.r),\(picked.g),\(picked.b))")
            }
        case .bucket, .magicWand, .textBubble, .transform:
            dragStartCanvasPt = mapped.canvas
            dragStartNormPt = mapped.norm
        case .rectSelect, .panelKnife:
            dragStartCanvasPt = mapped.canvas
            dragStartNormPt = mapped.norm
            ctrl.s2LiveMarqueeStartNorm = mapped.norm
            ctrl.s2LiveMarqueeCurrentNorm = mapped.norm
        case .lasso:
            lassoCanvasPts = [mapped.canvas]
            lassoNormPts = [mapped.norm]
            ctrl.s2LiveLassoNorm = lassoNormPts
        case .brush, .eraser, .smudge, .blur:
            if ctrl.s2Tool == .brush && ctrl.s2ShapeAssist != .freehand {
                dragStartCanvasPt = mapped.canvas
                dragStartNormPt = mapped.norm
                ctrl.s2LiveMarqueeStartNorm = mapped.norm
                ctrl.s2LiveMarqueeCurrentNorm = mapped.norm
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
           let panTouch = activeTouch ?? touches.first
        {
            let cur = panTouch.location(in: superview ?? self)
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
            ctrl.s2EyedropperLoupeNorm = mapped.norm
            if let picked = ctrl.sampleEyedropper(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y)) {
                onStatusUpdate?("吸色预览 Eyedropper: \(picked.hexString) (RGB \(picked.r),\(picked.g),\(picked.b))")
            }
        case .rectSelect, .panelKnife:
            ctrl.s2LiveMarqueeCurrentNorm = mapped.norm
        case .lasso:
            lassoCanvasPts.append(mapped.canvas)
            lassoNormPts.append(mapped.norm)
            ctrl.s2LiveLassoNorm = lassoNormPts
        case .brush, .eraser, .smudge, .blur:
            if ctrl.s2Tool == .brush && ctrl.s2ShapeAssist != .freehand {
                ctrl.s2LiveMarqueeCurrentNorm = mapped.norm
                return
            }
            processCoalescedStrokeSamples(touch: touch, event: event, ctrl: ctrl)
        default:
            break
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if fingerPanPrevLocation != nil {
            fingerPanPrevLocation = nil
            activeTouch = nil
            if let ctrl = controller {
                onStatusUpdate?("Canvas panned (\(Int(ctrl.s2PanOffset.width)), \(Int(ctrl.s2PanOffset.height)))")
            }
            return
        }
        guard let ctrl = controller, let touch = activeTouch, touches.contains(touch) else { return }
        let mapped = mapToCanvas(touch.preciseLocation(in: self))

        switch ctrl.s2Tool {
        case .eyedropper:
            if let picked = ctrl.sampleEyedropper(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y)) {
                if ctrl.s2EyedropperAutoSwitchToBrush {
                    ctrl.s2Tool = .brush
                    onStatusUpdate?("已提取颜色 \(picked.hexString) → 自动切回画笔 Brush")
                } else {
                    onStatusUpdate?("已提取颜色 Picked \(picked.hexString)")
                }
            }
            ctrl.s2EyedropperLoupeNorm = nil
        case .bucket:
            let filled = ctrl.applyBucketFill(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y))
            onStatusUpdate?("Close-Gap Bucket filled \(filled) px")
        case .magicWand:
            let count = ctrl.applyMagicWandSelection(canvasX: Int(mapped.canvas.x), canvasY: Int(mapped.canvas.y))
            onStatusUpdate?("Magic Wand selected \(count) px · 可在上方选区栏填充/擦除/扩缩")
        case .textBubble:
            ctrl.addSpeechBubble(normX: Double(mapped.norm.x), normY: Double(mapped.norm.y))
            onStatusUpdate?(ctrl.lastStatusBanner)
        case .panelKnife:
            if let start = dragStartCanvasPt {
                let count = ctrl.slicePanelFrame(from: start, to: mapped.canvas, gutterPx: Float(ctrl.s2PanelGutterPx))
                onStatusUpdate?("Panel Knife sliced frame (\(count) panels)")
            }
            ctrl.s2LiveMarqueeStartNorm = nil
            ctrl.s2LiveMarqueeCurrentNorm = nil
        case .rectSelect:
            if let sNorm = dragStartNormPt, let sCanvas = dragStartCanvasPt {
                let normRect = CGRect(
                    x: min(sNorm.x, mapped.norm.x),
                    y: min(sNorm.y, mapped.norm.y),
                    width: max(0.01, abs(mapped.norm.x - sNorm.x)),
                    height: max(0.01, abs(mapped.norm.y - sNorm.y))
                )
                let canvasRect = CGRect(
                    x: min(sCanvas.x, mapped.canvas.x),
                    y: min(sCanvas.y, mapped.canvas.y),
                    width: max(4.0, abs(mapped.canvas.x - sCanvas.x)),
                    height: max(4.0, abs(mapped.canvas.y - sCanvas.y))
                )
                let count = ctrl.setMarqueeSelection(canvasRect: canvasRect, normRect: normRect)
                onStatusUpdate?("选区已建立 (\(count) px) · 请使用选区操作栏填充/擦除/调整")
            }
            ctrl.s2LiveMarqueeStartNorm = nil
            ctrl.s2LiveMarqueeCurrentNorm = nil
        case .lasso:
            if lassoCanvasPts.count >= 3 {
                let count = ctrl.setLassoSelection(canvasPoints: lassoCanvasPts, normPoints: lassoNormPts)
                onStatusUpdate?("套索已选中 \(count) px · 请在上方/底部选区栏进行填充、清除或扩缩调整")
            }
            lassoCanvasPts.removeAll()
            lassoNormPts.removeAll()
            ctrl.s2LiveLassoNorm.removeAll()
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
                ctrl.s2LiveMarqueeStartNorm = nil
                ctrl.s2LiveMarqueeCurrentNorm = nil
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
        lassoCanvasPts.removeAll()
        lassoNormPts.removeAll()
        controller?.s2LiveLassoNorm.removeAll()
        controller?.s2LiveMarqueeStartNorm = nil
        controller?.s2LiveMarqueeCurrentNorm = nil
        controller?.s2EyedropperLoupeNorm = nil
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
