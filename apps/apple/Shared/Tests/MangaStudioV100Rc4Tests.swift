import Foundation
import XCTest

/// Live M5 Pro Apple Silicon verification suite for **`v1.0.0-rc4` (Phase 3)**:
/// 1. All 6 pulled-forward ibisPaint FX Filters (`Gaussian Blur`, `HSB`, `Brightness/Contrast`,
///    `Extract Line Drawing`, `Outer Stroke`, `Drop Shadow`) + single-step Rust CoW Undo.
/// 2. Interactive Affine Transform, Procedural Screentone fill, Panel Knife slicing + border rasterization,
///    Shape Assist (`Line`/`Rect`/`Ellipse`), and Symmetry Ruler live dual-side mirroring.
/// 3. Speech Bubbles & Floating Reference Window persistence across cold app restart.
@MainActor
final class MangaStudioV100Rc4Tests: XCTestCase {

    func testAllSixPulledForwardFxFiltersAndSingleStepUndoViaCAbi() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc4Fx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "FxPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("FxPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
        ctrl.setActiveColor(PersistedRGBA(r: 240, g: 40, b: 40, a: 255))
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 120, y: 120), to: CGPoint(x: 180, y: 120), radiusPx: 14, hardness: 1.0, opacity: 1.0)
        ctrl.refreshCompositeImage()

        // 1. HSB shift +120° turns red stroke green
        XCTAssertGreaterThan(ctrl.applyFilterHsb(hueDeg: 120, satDelta: 0, brightDelta: 0), 500)
        let greenPx = ctrl.rustProject?.sampleEyedropper(x: 150, y: 120)
        XCTAssertGreaterThan(greenPx?.1 ?? 0, 180)

        // Single-step Undo restores exact red stroke immediately!
        ctrl.performUndoStroke()
        let restoredRed = ctrl.rustProject?.sampleEyedropper(x: 150, y: 120)
        XCTAssertGreaterThan(restoredRed?.0 ?? 0, 200)

        // 2. Brightness & Contrast
        XCTAssertGreaterThan(ctrl.applyFilterBrightnessContrast(brightness: 0.1, contrast: 0.2), 500)

        // 3. Outer Stroke adds yellow border around stroke
        XCTAssertGreaterThan(ctrl.applyFilterOuterStroke(widthPx: 4, color: PersistedRGBA(r: 255, g: 230, b: 0, a: 255)), 200)

        // 4. Drop Shadow casts blurred shadow behind artwork
        XCTAssertGreaterThan(ctrl.applyFilterDropShadow(dx: 8, dy: 8, blurPx: 3.0, color: PersistedRGBA(r: 0, g: 0, b: 0, a: 180)), 200)

        // 5. Gaussian Blur softens layer
        XCTAssertGreaterThan(ctrl.applyFilterGaussianBlur(radiusPx: 2.5), 200)

        // 6. Extract Line Drawing strips white pixels to transparent and keeps dark ink
        ctrl.addLayer()
        ctrl.setActiveColor(PersistedRGBA(r: 250, g: 250, b: 250, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 60, y: 50), radiusPx: 8, hardness: 1.0, opacity: 1.0)
        ctrl.setActiveColor(PersistedRGBA(r: 10, g: 10, b: 10, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 80, y: 50), to: CGPoint(x: 90, y: 50), radiusPx: 8, hardness: 1.0, opacity: 1.0)
        XCTAssertGreaterThan(ctrl.applyFilterExtractLineDrawing(blackThreshold: 0.25, whiteThreshold: 0.85), 100)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 55, y: 50)?.3, 0)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 85, y: 50)?.3, 255)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testTransformScreentonePanelKnifeShapeAssistAndSymmetryRuler() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc4Tools-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "ToolsPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("ToolsPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
        ctrl.setActiveColor(PersistedRGBA(r: 30, g: 120, b: 255, a: 255))

        // Symmetry ruler mirrors live stroke across vertical axis (width = 800 -> x=150 mirrors to x=650)
        ctrl.s2RulerMode = .symmetry
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRulerAwareRasterSegment(
            from: CGPoint(x: 150, y: 200),
            to: CGPoint(x: 160, y: 200),
            anchor: CGPoint(x: 150, y: 200),
            radiusPx: 10, hardness: 1.0, opacity: 1.0
        )
        ctrl.refreshCompositeImage()
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 155, y: 200)?.2, 255)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 645, y: 200)?.2, 255)

        // Shape Assist commits crisp rectangle & ellipse raster pixels
        ctrl.s2RulerMode = .off
        XCTAssertGreaterThan(ctrl.drawRasterShape(kind: .rectangle, from: CGPoint(x: 200, y: 300), to: CGPoint(x: 340, y: 420), radiusPx: 4, hardness: 1.0, opacity: 1.0), 300)
        XCTAssertGreaterThan(ctrl.drawRasterShape(kind: .ellipse, from: CGPoint(x: 400, y: 300), to: CGPoint(x: 520, y: 420), radiusPx: 4, hardness: 1.0, opacity: 1.0), 300)

        // Affine Transform shifts layer content cleanly
        XCTAssertGreaterThan(ctrl.applyAffineTransform(dx: 24, dy: -16, scaleX: 1.05, scaleY: 1.05, rotDeg: 5), 200)

        // Procedural Screentone fills active selection with halftone dots
        _ = ctrl.setMarqueeSelection(canvasRect: CGRect(x: 100, y: 600, width: 140, height: 140), normRect: CGRect(x: 0.125, y: 0.53, width: 0.175, height: 0.12))
        let tonePx = ctrl.applyScreentoneFill(lpi: 60, density: 0.35, patternCode: 0)
        XCTAssertGreaterThan(tonePx, 1000)
        ctrl.clearCanvasSelection()

        // Panel Knife slices page frame horizontally into 2 panels & rasterizes borders
        let panelCount = ctrl.slicePanelFrame(from: CGPoint(x: 0, y: 560), to: CGPoint(x: 800, y: 560), gutterPx: 16)
        XCTAssertGreaterThanOrEqual(panelCount, 2)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testSpeechBubblesAndReferenceWindowPersistAcrossColdRestart() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc4Bubbles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #if canImport(MangaCoreFFI)
        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "BubblePrj", author: "M5Pro"))
        #endif
        let prjDir = tmp.appendingPathComponent("BubblePrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        do {
            let s1 = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
            s1.s2ShowReferenceWindow = true
            s1.addSpeechBubble(normX: 0.35, normY: 0.25, text: "星辉一闪！", isVertical: true)
            s1.addSpeechBubble(normX: 0.72, normY: 0.65, text: "Starlight Slash!", isVertical: false)
            s1.flushAllSync()
        }

        let s2 = StudioWorkspaceController(appStateFileUrl: appStateUrl)
        XCTAssertTrue(s2.s2ShowReferenceWindow)
        XCTAssertEqual(s2.s2SpeechBubbles.count, 2)
        XCTAssertEqual(s2.s2SpeechBubbles[0].text, "星辉一闪！")
        XCTAssertTrue(s2.s2SpeechBubbles[0].isVertical)
        XCTAssertEqual(s2.s2SpeechBubbles[1].text, "Starlight Slash!")
        XCTAssertFalse(s2.s2SpeechBubbles[1].isVertical)
    }
}
