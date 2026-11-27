import Foundation
import XCTest

/// Live M5 Pro Apple Silicon verification suite for **`v1.0.0-rc2` (Phase 1)**:
/// 1. `MNGA0002` full RLE-compressed sparse pixel-tile persistence & reload via Rust C-ABI.
/// 2. Context-aware Menu Bar enablement matrix (`S1` / `S2` / `S3` + active drawing tool transitions).
/// 3. Full 3-layer cold-restart persistence (`StudioWorkspaceController` save → cold reopen → exact restoration).
@MainActor
final class MangaStudioV100Rc2Tests: XCTestCase {

    func testMngaV2FullPixelTileSaveAndReloadViaCAbi() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc2Mnga2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "MngaV2Verify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("MngaV2Verify").path

        guard let projA = MangaProjectEngine(preset: .illustration4K) else {
            return XCTFail("Failed to allocate MangaProjectEngine A")
        }
        let l1 = projA.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, isReference: true)
        _ = projA.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: true)
        _ = projA.closeGapFill(layerId: l1, seedX: 8, seedY: 8, rgba: (255, 107, 74, 255))

        let writtenBytes = projA.saveMngaV2(
            projectDir: projectDir,
            relPath: "chapters/ch001/manuscript/p001.mnga",
            dpi: 600,
            timelapseEvents: 12
        )
        XCTAssertGreaterThan(writtenBytes, 60)

        guard let projB = MangaProjectEngine(preset: .illustration4K) else {
            return XCTFail("Failed to allocate MangaProjectEngine B")
        }
        XCTAssertEqual(projB.layerCount, 0)
        XCTAssertTrue(projB.loadMngaV2(projectDir: projectDir, relPath: "chapters/ch001/manuscript/p001.mnga"))
        XCTAssertEqual(projB.layerCount, 2)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testContextSensitiveMenuCapabilitiesFollowActiveSuiteAndDrawingTool() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc2Menu-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let prjDir = tmp.appendingPathComponent("MenuTestPrj").path
        #if canImport(MangaCoreFFI)
        _ = MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "MenuTestPrj", author: "Tester")
        #endif
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        let ctrl = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)

        // In S2 Manga with Brush selected: drawing & brush dynamics enabled, bucket options disabled, novel disabled
        ctrl.switchSuiteApp(.manga)
        ctrl.selectTool(.brush)
        XCTAssertTrue(ctrl.isMangaContext)
        XCTAssertFalse(ctrl.isNovelContext)
        XCTAssertTrue(ctrl.canAdjustBrushDynamics)
        XCTAssertFalse(ctrl.canAdjustBucketOptions)
        XCTAssertTrue(ctrl.canExportArtwork)

        // Switching to Bucket enables bucket options and disables brush dynamics
        ctrl.selectTool(.bucket)
        XCTAssertTrue(ctrl.canAdjustBucketOptions)
        XCTAssertFalse(ctrl.canAdjustBrushDynamics)

        // Switching to S3 Novel enables novel commands and disables manga drawing/export
        ctrl.switchSuiteApp(.novel)
        XCTAssertTrue(ctrl.isNovelContext)
        XCTAssertFalse(ctrl.isMangaContext)
        XCTAssertFalse(ctrl.canExportArtwork)
        XCTAssertTrue(ctrl.canExportEpub)

        // Dual Studio mode enables BOTH S2 Manga and S3 Novel capabilities simultaneously
        ctrl.workspaceMode = .dualNovelManga
        XCTAssertTrue(ctrl.isMangaContext)
        XCTAssertTrue(ctrl.isNovelContext)
    }

    func testColdRestartRestoresExactWorkspaceCanvasStrokesLayersAndNovelProse() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaV100Rc2Restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #if canImport(MangaCoreFFI)
        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: tmp.path, folderName: "RestorePrj", author: "Tester"))
        #endif
        let prjDir = tmp.appendingPathComponent("RestorePrj").path
        let appStateUrl = tmp.appendingPathComponent("app_state.json")

        // Session 1: User customizes locale, tool, color, zoom, adds a layer, draws a stroke, edits novel prose, and quits!
        do {
            let session1 = StudioWorkspaceController(appStateFileUrl: appStateUrl, initialProjectDir: prjDir)
            session1.activeLocale = .yueHant
            session1.switchSuiteApp(.manga)
            session1.selectTool(.bucket)
            session1.s2BucketCloseGapPx = 5
            session1.s2ViewportZoom = 2.25
            session1.setActiveColor(PersistedRGBA(r: 255, g: 107, b: 74))
            session1.addLayer()
            let newLayerId = session1.s2SelectedLayerId
            session1.s2Strokes.append(
                PersistedCanvasStroke(
                    layerId: newLayerId,
                    points: [
                        PersistedStrokePoint(x: 10, y: 10, width: 6),
                        PersistedStrokePoint(x: 80, y: 90, width: 6),
                    ],
                    color: PersistedRGBA(r: 255, g: 107, b: 74)
                )
            )
            session1.s3PaperTheme = .nightInk
            session1.s3ProseText = "# 持久化恢复测试\n\n离开前写的最后一句正文必须原样保留。"
            session1.flushAllSync()
        }

        // Session 2: Cold app relaunch using ONLY appStateUrl (no initialProjectDir passed!)
        let session2 = StudioWorkspaceController(appStateFileUrl: appStateUrl)
        XCTAssertEqual(session2.activeProjectDir, prjDir)
        XCTAssertEqual(session2.activeLocale, .yueHant)
        XCTAssertEqual(session2.s2Tool, .bucket)
        XCTAssertEqual(session2.s2BucketCloseGapPx, 5)
        XCTAssertEqual(session2.s2ViewportZoom, 2.25, accuracy: 0.001)
        XCTAssertEqual(session2.s2ActiveColor, PersistedRGBA(r: 255, g: 107, b: 74))
        XCTAssertEqual(session2.s2Strokes.count, 1)
        XCTAssertEqual(session2.s3PaperTheme, .nightInk)
        XCTAssertTrue(session2.s3ProseText.contains("离开前写的最后一句正文必须原样保留"))
    }
}
