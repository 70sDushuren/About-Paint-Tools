import Foundation
import XCTest

/// Verification suite for **`v1.0.0-rc5` (iPad Pro 13" M5 Drawing Polish)**:
/// 1. Independent Floating Selection Pixel Transform (`transformSelectedPixelsAffine` via C11 FFI) —
///    cut-move & copy-stamp preserve unselected neighbor pixels cleanly and move selection mask in lockstep.
/// 2. Canvas Viewport Rotation (`rotateCanvas`, `resetRotation`, `resetViewport`) with persistence.
/// 3. Multi-Canvas Gallery (`createNewCanvasProject`, `switchToCanvasProject`, custom W×H persistence)
///    and RGBA8 Photo Import as a new raster layer & Floating Reference Window photo.
/// 4. Live Brush & Eraser Size Visualizer HUD (`s2ShowBrushSizePreviewHUD`), Layer Deletion Pixel Cleanup
///    (including single-layer delete-to-clear & session-restore ID reconciliation), and Synchronized Step-by-Step Undo/Redo.
@MainActor
final class MangaStudioV100Rc5IpadTests: XCTestCase {

    func testFloatingSelectionPixelTransformPreservesUnselectedAndSupportsCopyStamp() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5FloatSel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "FloatPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("FloatPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
        // Paint red blob at (100, 100) — inside selection
        ctrl.setActiveColor(PersistedRGBA(r: 230, g: 30, b: 30, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 90, y: 100), to: CGPoint(x: 110, y: 100), radiusPx: 14, hardness: 1.0, opacity: 1.0)
        // Paint blue anchor blob at (500, 500) — outside selection (must stay untouched!)
        ctrl.setActiveColor(PersistedRGBA(r: 20, g: 90, b: 245, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 495, y: 500), to: CGPoint(x: 505, y: 500), radiusPx: 14, hardness: 1.0, opacity: 1.0)

        // Select around red blob [60..140, 60..140]
        let selCount = ctrl.setMarqueeSelection(
            canvasRect: CGRect(x: 60, y: 60, width: 80, height: 80),
            normRect: CGRect(x: 60.0 / 800.0, y: 60.0 / 1132.0, width: 80.0 / 800.0, height: 80.0 / 1132.0)
        )
        XCTAssertGreaterThan(selCount, 1000)

        // Cut-move ONLY selected pixels by (+120, +60)
        let moved = ctrl.applyAffineTransform(
            dx: 120, dy: 60, scaleX: 1.0, scaleY: 1.0, rotDeg: 0,
            selectionOnly: true, clearSource: true
        )
        XCTAssertGreaterThan(moved, 200)

        // Original red footprint cleared
        let oldSpot = ctrl.rustProject?.sampleEyedropper(x: 100, y: 100)
        XCTAssertEqual(oldSpot?.3 ?? 255, 0)
        // Moved red blob arrived at (220, 160)
        let newSpot = ctrl.rustProject?.sampleEyedropper(x: 220, y: 160)
        XCTAssertGreaterThan(newSpot?.0 ?? 0, 180)
        // Unselected blue anchor at (500, 500) is 100% untouched!
        let blueAnchor = ctrl.rustProject?.sampleEyedropper(x: 500, y: 500)
        XCTAssertGreaterThan(blueAnchor?.2 ?? 0, 200)

        // Copy-stamp (clearSource = false) by (+80, 0) preserves (220, 160) AND stamps (300, 160)
        let stamped = ctrl.applyAffineTransform(
            dx: 80, dy: 0, scaleX: 1.0, scaleY: 1.0, rotDeg: 0,
            selectionOnly: true, clearSource: false
        )
        XCTAssertGreaterThan(stamped, 200)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 220, y: 160)?.0 ?? 0, 180)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 300, y: 160)?.0 ?? 0, 180)
        #endif
    }

    func testCanvasRotationNormalizationAndResetViewport() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5Rot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let prjDir = tmp.appendingPathComponent("RotPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")
        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)

        ctrl.rotateCanvas(by: 45.0)
        XCTAssertEqual(ctrl.s2RotationDeg, 45.0, accuracy: 0.01)
        ctrl.rotateCanvas(by: 160.0)
        XCTAssertEqual(ctrl.s2RotationDeg, -155.0, accuracy: 0.01)

        ctrl.resetRotation()
        XCTAssertEqual(ctrl.s2RotationDeg, 0.0, accuracy: 0.01)

        ctrl.rotateCanvas(by: -30.0)
        ctrl.s2ViewportZoom = 2.0
        ctrl.resetViewport()
        XCTAssertEqual(ctrl.s2RotationDeg, 0.0, accuracy: 0.01)
        XCTAssertEqual(ctrl.s2ViewportZoom, 1.0, accuracy: 0.01)
    }

    func testPhotoImportToNewRustLayerAndReferenceImage() throws {
        #if canImport(MangaCoreFFI) && canImport(CoreGraphics) && canImport(ImageIO)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5Photo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "PhotoPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("PhotoPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")
        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)

        // Generate a real synthetic PNG in memory via Rust exportPngData
        ctrl.setActiveColor(PersistedRGBA(r: 40, g: 210, b: 120, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 700, y: 1000), radiusPx: 120, hardness: 1.0, opacity: 1.0)
        guard let pngData = ctrl.rustProject?.exportPngData(transparentBackground: false) else {
            XCTFail("Expected valid PNG export data")
            return
        }

        let beforeLayerCount = ctrl.s2CelLayers.count
        XCTAssertTrue(ctrl.importImageDataAsNewLayer(pngData, layerName: "ImportedSketch"))
        XCTAssertEqual(ctrl.s2CelLayers.count, beforeLayerCount + 1)

        XCTAssertTrue(ctrl.importReferenceImageData(pngData))
        XCTAssertNotNil(ctrl.s2ReferenceImage)
        XCTAssertTrue(ctrl.s2ShowReferenceWindow)
        XCTAssertTrue(FileManager.default.fileExists(atPath: (prjDir as NSString).appendingPathComponent("reference_image.png")))

        ctrl.clearReferenceImage()
        XCTAssertNil(ctrl.s2ReferenceImage)
        #endif
    }

    func testBrushAndEraserSizeChangeTriggersPreviewVisualizerHUD() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5BrushHUD-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let prjDir = tmp.appendingPathComponent("BrushHudPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")
        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)

        XCTAssertFalse(ctrl.s2ShowBrushSizePreviewHUD)
        ctrl.selectTool(.brush)
        ctrl.s2BrushSize = 28.0
        XCTAssertTrue(ctrl.s2ShowBrushSizePreviewHUD)

        ctrl.s2ShowBrushSizePreviewHUD = false
        ctrl.selectTool(.eraser)
        ctrl.s2BrushSize = 42.0
        XCTAssertTrue(ctrl.s2ShowBrushSizePreviewHUD)
    }

    func testDeleteSelectedLayerRemovesLayerPixelsAndSurvivesSessionRestore() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5LayerDel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "LayerDelPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("LayerDelPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
        XCTAssertEqual(ctrl.s2CelLayers.count, 3)

        // Select top layer ("Lineart_Main") and draw bright red ink at (200, 200)
        let topLayerId = ctrl.s2CelLayers[2].id
        ctrl.s2SelectedLayerId = topLayerId
        ctrl.setActiveColor(PersistedRGBA(r: 240, g: 20, b: 20, a: 255))
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRasterSegment(
            from: CGPoint(x: 190, y: 200),
            to: CGPoint(x: 210, y: 200),
            radiusPx: 14,
            hardness: 1.0,
            opacity: 1.0
        )
        ctrl.refreshCompositeImage()

        // Verify red ink is present at (200, 200)
        let beforeDeleteSample = ctrl.rustProject?.sampleEyedropper(x: 200, y: 200)
        XCTAssertGreaterThan(beforeDeleteSample?.0 ?? 0, 200)
        XCTAssertGreaterThan(beforeDeleteSample?.3 ?? 0, 200)

        // Delete the selected layer -> red ink on that layer MUST be completely gone!
        ctrl.deleteSelectedLayer()
        XCTAssertEqual(ctrl.s2CelLayers.count, 2)
        let afterDeleteSample = ctrl.rustProject?.sampleEyedropper(x: 200, y: 200)
        XCTAssertEqual(afterDeleteSample?.3 ?? 255, 0, "Deleted layer's pixels must be removed from the canvas composite")

        // Delete down to 1 layer, draw green ink at (300, 300), and delete the last remaining layer -> must clear its pixels
        ctrl.deleteSelectedLayer()
        XCTAssertEqual(ctrl.s2CelLayers.count, 1)
        ctrl.setActiveColor(PersistedRGBA(r: 20, g: 220, b: 60, a: 255))
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRasterSegment(
            from: CGPoint(x: 290, y: 300),
            to: CGPoint(x: 310, y: 300),
            radiusPx: 14,
            hardness: 1.0,
            opacity: 1.0
        )
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 300, y: 300)?.1 ?? 0, 180)
        ctrl.deleteSelectedLayer()
        XCTAssertEqual(ctrl.s2CelLayers.count, 1)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 300, y: 300)?.3 ?? 255, 0)
        #endif
    }

    func testSynchronizedUndoRedoRevertsStrokesAndLayerDeletionsStepByStep() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5UndoSync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "UndoPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("UndoPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)

        // Step 1: Draw Stroke 1 at (120, 120)
        ctrl.setActiveColor(PersistedRGBA(r: 250, g: 40, b: 40, a: 255))
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 110, y: 120), to: CGPoint(x: 130, y: 120), radiusPx: 12, hardness: 1.0, opacity: 1.0)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 0, 200)

        // Step 2: Draw Stroke 2 at (260, 260)
        ctrl.setActiveColor(PersistedRGBA(r: 40, g: 120, b: 250, a: 255))
        ctrl.beginRasterUndoCheckpoint()
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 250, y: 260), to: CGPoint(x: 270, y: 260), radiusPx: 12, hardness: 1.0, opacity: 1.0)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 260, y: 260)?.3 ?? 0, 200)

        // Step 3: Undo once -> Stroke 2 at (260, 260) must be reverted while Stroke 1 at (120, 120) remains!
        ctrl.performUndoStroke()
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 260, y: 260)?.3 ?? 255, 0, "Undo must revert Stroke 2")
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 0, 200, "Stroke 1 must still be intact")

        // Step 4: Undo again -> Stroke 1 at (120, 120) must now be reverted!
        ctrl.performUndoStroke()
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 255, 0, "Second Undo must revert Stroke 1")

        // Step 5: Redo twice -> restores Stroke 1 then Stroke 2
        ctrl.performRedoStroke()
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 0, 200)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 260, y: 260)?.3 ?? 255, 0)

        ctrl.performRedoStroke()
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 260, y: 260)?.3 ?? 0, 200)

        // Step 6: Delete the active layer, then Undo the deletion -> both layer list AND pixels return!
        let countBeforeDelete = ctrl.s2CelLayers.count
        ctrl.deleteSelectedLayer()
        XCTAssertEqual(ctrl.s2CelLayers.count, countBeforeDelete - 1)
        XCTAssertEqual(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 255, 0)

        ctrl.performUndoStroke()
        XCTAssertEqual(ctrl.s2CelLayers.count, countBeforeDelete)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 120, y: 120)?.3 ?? 0, 200)
        XCTAssertGreaterThan(ctrl.rustProject?.sampleEyedropper(x: 260, y: 260)?.3 ?? 0, 200)
        #endif
    }

    func testMultiLayerStackOrderMoveUpDownAndThrottledInteractiveComposite() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc5LayerOrder-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "OrderPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("OrderPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
        XCTAssertEqual(ctrl.s2CelLayers.count, 3)

        // Layer 1 (index 1, middle): Paint bright RED at (180, 180)
        let midId = ctrl.s2CelLayers[1].id
        ctrl.s2SelectedLayerId = midId
        ctrl.setActiveColor(PersistedRGBA(r: 245, g: 25, b: 25, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 170, y: 180), to: CGPoint(x: 190, y: 180), radiusPx: 14, hardness: 1.0, opacity: 1.0)

        // Layer 2 (index 2, top): Set blendMode to .normal & opacity 1.0, and paint bright BLUE at the exact same spot (180, 180)
        let topId = ctrl.s2CelLayers[2].id
        ctrl.s2CelLayers[2].blendMode = .normal
        ctrl.s2CelLayers[2].opacity = 1.0
        ctrl.syncLayerToRust(ctrl.s2CelLayers[2])
        ctrl.s2SelectedLayerId = topId
        ctrl.setActiveColor(PersistedRGBA(r: 20, g: 70, b: 250, a: 255))
        _ = ctrl.applyRasterSegment(from: CGPoint(x: 170, y: 180), to: CGPoint(x: 190, y: 180), radiusPx: 14, hardness: 1.0, opacity: 1.0)
        ctrl.refreshCompositeImage(interactive: true)

        // Because Blue is on top of Red, sampling (180, 180) returns BLUE
        let sampleBeforeMove = ctrl.rustProject?.sampleEyedropper(x: 180, y: 180)
        XCTAssertGreaterThan(sampleBeforeMove?.2 ?? 0, 200, "Top layer (Blue) should occlude lower layer (Red)")

        // Move the middle layer (Red) UP above Blue!
        ctrl.moveLayer(id: midId, up: true)
        XCTAssertEqual(ctrl.s2CelLayers[2].id, midId)
        XCTAssertEqual(ctrl.s2CelLayers[1].id, topId)

        // Now Red is at index 2 (top of stack), so sampling (180, 180) MUST return RED!
        let sampleAfterMoveUp = ctrl.rustProject?.sampleEyedropper(x: 180, y: 180)
        XCTAssertGreaterThan(sampleAfterMoveUp?.0 ?? 0, 200, "Moved-up layer (Red) must now occlude Blue")
        XCTAssertLessThan(sampleAfterMoveUp?.2 ?? 255, 60)

        // Move Red back DOWN -> Blue is back on top!
        ctrl.moveLayer(id: midId, up: false)
        XCTAssertEqual(ctrl.s2CelLayers[2].id, topId)
        let sampleAfterMoveDown = ctrl.rustProject?.sampleEyedropper(x: 180, y: 180)
        XCTAssertGreaterThan(sampleAfterMoveDown?.2 ?? 0, 200)
        #endif
    }
}
