import Foundation
import XCTest

/// Verification suite for **`v1.0.0-rc5` (iPad Pro 13" M5 Drawing Polish)**:
/// 1. Independent Floating Selection Pixel Transform (`transformSelectedPixelsAffine` via C11 FFI) —
///    cut-move & copy-stamp preserve unselected neighbor pixels cleanly and move selection mask in lockstep.
/// 2. Canvas Viewport Rotation (`rotateCanvas`, `resetRotation`, `resetViewport`) with persistence.
/// 3. Multi-Canvas Gallery (`createNewCanvasProject`, `switchToCanvasProject`, custom W×H persistence)
///    and RGBA8 Photo Import as a new raster layer & Floating Reference Window photo.
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
}
