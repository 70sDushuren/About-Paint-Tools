import Foundation
import XCTest

/// Live M5 Pro Apple Silicon verification suite for **`v1.0.0-rc3` (Phase 2)**:
/// 1. Real Rust RGBA8 raster painting, transparent erasing, smudge, blur, Eyedropper & live `CGImage`.
/// 2. Marquee / Lasso / Magic Wand selection masking + 22 blend modes + Rust Layer CRUD & Undo/Redo snapshots.
/// 3. Real PNG (`89 50 4E 47`) & Adobe PSD (`8BPS`) disk exports + pixel-exact `MNGA0002` cold restart.
@MainActor
final class MangaStudioV100Rc3Tests: XCTestCase {

    func testRealRasterPaintEraseSmudgeBlurEyedropperAndCGImageViaCAbi() throws {
        #if canImport(MangaCoreFFI)
        guard let proj = MangaProjectEngine(width: 256, height: 256) else {
            return XCTFail("Failed to create 256x256 MangaProjectEngine")
        }
        let inkId = proj.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, isReference: true)

        // Paint coral red line across y=128
        proj.pushUndoSnapshot()
        let painted = proj.paintSegment(
            layerId: inkId,
            x0: 40, y0: 128, x1: 200, y1: 128,
            radiusPx: 10, hardness: 0.95, opacity: 1.0,
            rgba: (255, 80, 60, 255)
        )
        XCTAssertGreaterThan(painted, 800)

        // Eyedropper samples exact coral RGBA
        let picked = proj.sampleEyedropper(x: 120, y: 128)
        XCTAssertEqual(picked?.0, 255)
        XCTAssertEqual(picked?.1, 80)
        XCTAssertEqual(picked?.2, 60)
        XCTAssertEqual(picked?.3, 255)

        // Transparent Eraser clears center alpha back to 0
        proj.pushUndoSnapshot()
        let erased = proj.eraseSegment(
            layerId: inkId,
            x0: 120, y0: 128, x1: 120, y1: 128,
            radiusPx: 8, hardness: 1.0, opacity: 1.0
        )
        XCTAssertGreaterThan(erased, 50)
        XCTAssertEqual(proj.sampleEyedropper(x: 120, y: 128)?.3, 0)

        // Undo restores coral pixel immediately!
        XCTAssertTrue(proj.undoSnapshot())
        XCTAssertEqual(proj.sampleEyedropper(x: 120, y: 128)?.3, 255)

        // Smudge & Blur operate cleanly on pixels
        XCTAssertGreaterThan(proj.smudgeSegment(layerId: inkId, x0: 60, y0: 128, x1: 60, y1: 150, radiusPx: 8, strength: 0.8), 20)
        XCTAssertGreaterThan(proj.blurSegment(layerId: inkId, x0: 170, y0: 128, x1: 180, y1: 128, radiusPx: 8, strength: 0.8), 20)

        // Live CGImage renders non-nil 256x256 RGBA8 image
        #if canImport(CoreGraphics)
        let cg = proj.makeCGImage(backdropCode: 0)
        XCTAssertNotNil(cg)
        XCTAssertEqual(cg?.width, 256)
        XCTAssertEqual(cg?.height, 256)
        #endif
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testSelectionMaskMagicWand22BlendModesAndLayerCrud() throws {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(LayerBlendMode.allCases.count, 22)

        guard let proj = MangaProjectEngine(width: 128, height: 128) else {
            return XCTFail("Failed to allocate MangaProjectEngine")
        }
        let l1 = proj.addRasterLayer(name: "Base", blendMode: .normal)

        // Marquee selection restricts painting strictly to [20..60, 20..60]
        let selCount = proj.setSelectionRect(x0: 20, y0: 20, x1: 60, y1: 60)
        XCTAssertEqual(selCount, 1600)
        _ = proj.paintSegment(
            layerId: l1,
            x0: 0, y0: 40, x1: 120, y1: 40,
            radiusPx: 6, hardness: 1.0, opacity: 1.0,
            rgba: (50, 140, 255, 255)
        )
        XCTAssertEqual(proj.sampleEyedropper(x: 40, y: 40)?.2, 255)
        XCTAssertEqual(proj.sampleEyedropper(x: 10, y: 40)?.3, 0)
        XCTAssertEqual(proj.sampleEyedropper(x: 90, y: 40)?.3, 0)

        // Magic Wand selects connected blue stripe
        proj.clearSelection()
        let wandCount = proj.setSelectionMagicWand(seedX: 40, seedY: 40, tolerance: 12, useReference: false)
        XCTAssertGreaterThan(wandCount, 100)
        XCTAssertLessThan(wandCount, 1200)

        // Duplicate, flip horizontally, apply Luminosity blend mode (#21), and merge down
        let l2 = proj.duplicateLayer(layerId: l1)
        XCTAssertNotEqual(l2, 0)
        XCTAssertEqual(proj.layerCount, 2)
        XCTAssertTrue(proj.setLayerFlags(layerId: l2, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .luminosity, opacity: 0.9, blueSketchTint: false))
        XCTAssertTrue(proj.flipLayer(layerId: l2, horizontal: true))
        XCTAssertEqual(proj.mergeLayerDown(layerId: l2), l1)
        XCTAssertEqual(proj.layerCount, 1)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testControllerPngPsdExportsAndPixelExactMngaV2ColdRestart() throws {
        #if canImport(MangaCoreFFI)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc3Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "ExportPrj", author: "M5Pro"))
        let prjDir = tmp.appendingPathComponent("ExportPrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")
        let pngUrl = tmp.appendingPathComponent("out.png")
        let psdUrl = tmp.appendingPathComponent("out.psd")

        do {
            let s1 = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
            s1.setActiveColor(PersistedRGBA(r: 47, g: 168, b: 139, a: 255))
            s1.beginRasterUndoCheckpoint()
            _ = s1.applyRasterSegment(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 100), radiusPx: 12, hardness: 1.0, opacity: 1.0)
            s1.refreshCompositeImage()
            #if canImport(CoreGraphics)
            XCTAssertNotNil(s1.s2CompositeImage)
            #endif

            XCTAssertTrue(s1.exportCanvasPng(to: pngUrl, transparentBackground: false))
            XCTAssertTrue(s1.exportCanvasPsd(to: psdUrl))

            let pngBytes = try Data(contentsOf: pngUrl)
            XCTAssertGreaterThan(pngBytes.count, 100)
            XCTAssertEqual(Array(pngBytes.prefix(4)), [0x89, 0x50, 0x4E, 0x47]) // PNG magic

            let psdBytes = try Data(contentsOf: psdUrl)
            XCTAssertGreaterThan(psdBytes.count, 40)
            XCTAssertEqual(String(decoding: psdBytes.prefix(4), as: UTF8.self), "8BPS")

            s1.flushAllSync()
        }

        // Cold relaunch verifies painted raster pixels survived via MNGA0002!
        let s2 = StudioWorkspaceController(appStateFileUrl: appStateUrl)
        let restoredPx = s2.rustProject?.sampleEyedropper(x: 150, y: 100)
        XCTAssertEqual(restoredPx?.0, 47)
        XCTAssertEqual(restoredPx?.1, 168)
        XCTAssertEqual(restoredPx?.2, 139)
        XCTAssertEqual(restoredPx?.3, 255)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
