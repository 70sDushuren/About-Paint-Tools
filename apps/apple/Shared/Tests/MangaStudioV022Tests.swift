import Foundation
import XCTest

/// Live Swift ↔ Rust `MangaCoreFFI` & `v0.2.2` Tri-App design-system verification suite.
/// Runs directly on Apple Silicon macOS via `xcodebuild test` (`test-mac` GoNext action).
final class MangaStudioV022Tests: XCTestCase {

    func testTriAppRamBudgetsAndWriteOwnershipIsolation() {
        #if canImport(MangaCoreFFI)
        XCTAssertTrue(MangaSuitePolicy.isRustFfiLinked)
        XCTAssertEqual(MangaSuitePolicy.ramBudgetMb(for: .hub), 200)
        XCTAssertEqual(MangaSuitePolicy.ramBudgetMb(for: .manga), 1536)
        XCTAssertEqual(MangaSuitePolicy.ramBudgetMb(for: .novel), 120)

        // Decision #4 write-ownership guard: novel_meta.xml is exclusively S3 RW
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .novel, relativePath: "chapters/ch001/novel/novel_meta.xml"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .hub, relativePath: "chapters/ch001/novel/novel_meta.xml"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .manga, relativePath: "chapters/ch001/novel/novel_meta.xml"))

        // S1 owns manifest, S2 owns manuscript, S3 owns prose
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .hub, relativePath: "SampleManga.prj"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .manga, relativePath: "SampleManga.prj"))
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .manga, relativePath: "chapters/ch001/manuscript/p001.mnga"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .novel, relativePath: "chapters/ch001/manuscript/p001.mnga"))
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .novel, relativePath: "chapters/ch001/novel/prose/zh-Hans.md"))
        #else
        XCTFail("MangaCoreFFI XCFramework must be linked for Apple unit tests.")
        #endif
    }

    func testS1HubBootstrapsCanonicalCpffProjectOnDisk() throws {
        #if canImport(MangaCoreFFI)
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let ok = MangaHubProjectBootstrap.initProject(
            parentDir: tempRoot.path,
            folderName: "StarlightTest",
            author: "M5ProTester"
        )
        XCTAssertTrue(ok, "Rust manga_hub_init_project should succeed")

        let prjFile = tempRoot.appendingPathComponent("StarlightTest/StarlightTest.prj")
        let gitAttr = tempRoot.appendingPathComponent("StarlightTest/.gitattributes")
        let proseFile = tempRoot.appendingPathComponent("StarlightTest/chapters/ch001/novel/prose/zh-Hans.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: prjFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: gitAttr.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: proseFile.path))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS2BrushDynamicsAndSparseTileUndoRedoLifecycle() {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(MangaBrushDynamics.presetCount, 8)
        let lightRadius = MangaBrushDynamics.sampleRadius(presetCode: 0, pressure: 0.15, altitude: 1.2)
        let heavyRadius = MangaBrushDynamics.sampleRadius(presetCode: 0, pressure: 0.95, altitude: 1.2)
        XCTAssertGreaterThan(heavyRadius, lightRadius, "G-Pen radius should grow monotonically with pressure")

        let ropeAt1x = MangaBrushDynamics.zoomAdaptiveRope(baseScreenPx: 12.0, viewportZoom: 1.0)
        let ropeAt2x = MangaBrushDynamics.zoomAdaptiveRope(baseScreenPx: 12.0, viewportZoom: 2.0)
        XCTAssertLessThan(ropeAt2x, ropeAt1x, "Canvas rope radius must shrink inversely with zoom")

        guard let canvas = MangaCanvasEngine(preset: .b4PrintManga600Dpi) else {
            return XCTFail("Failed to allocate B4 600DPI sparse canvas")
        }
        XCTAssertEqual(canvas.width, 6071)
        XCTAssertEqual(canvas.height, 8598)
        XCTAssertEqual(canvas.allocatedTiles, 0, "Empty sparse canvas must allocate 0 tiles")

        canvas.beginStroke(radius: 6.0, rgba: (17, 18, 22, 255), isEraser: false, stabilizerRadius: 4.0)
        canvas.pushPoints([
            NativeStrokeSample(x: 120, y: 120, pressure: 0.7, altitude: 1.2, azimuth: 0, rollAngle: 0, timestampMs: 1, isPredicted: false),
            NativeStrokeSample(x: 160, y: 145, pressure: 0.85, altitude: 1.2, azimuth: 0, rollAngle: 0, timestampMs: 8, isPredicted: false),
        ])
        let dirty = canvas.endStroke()
        XCTAssertGreaterThan(dirty, 0)
        XCTAssertGreaterThan(canvas.allocatedTiles, 0)

        XCTAssertTrue(canvas.undo())
        XCTAssertEqual(canvas.allocatedTiles, 0, "CoW undo must restore empty tile allocation cleanly")
        XCTAssertTrue(canvas.redo())
        XCTAssertGreaterThan(canvas.allocatedTiles, 0)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS3NovelMixedCjkAndLatinWordCounting() {
        #if canImport(MangaCoreFFI)
        let sample = "星辉觉醒 Starlight Awakening 2026"
        let units = MangaNovelMetrics.countUnits(in: sample)
        // 4 CJK characters + 3 Latin/numeric tokens = 7 publishing units
        XCTAssertEqual(units, 7)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testDesignSystemIconAndThemeCatalogIntegrity() {
        XCTAssertEqual(SuiteIconGlyph.allCases.count, 18, "Decision #2 specifies 18 core MIT geometric icons")
        XCTAssertEqual(PaperThemeKind.allCases.count, 3, "S3 specifies Warm Paper, Sepia, and Night Ink themes")
        XCTAssertEqual(StudioWorkspaceMode.allCases.count, 3)
    }

    func testS1RenamedFolderFallbackDetectionOnDisk() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioFallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: root.path, folderName: "OrigWork", author: "Tester"))
        let origDir = root.appendingPathComponent("OrigWork")
        XCTAssertEqual(MangaHubProjectBootstrap.resolvePrjStatus(projectDir: origDir.path), .exactMatch)

        let renamedDir = root.appendingPathComponent("OrigWork-GitCloneCopy")
        try FileManager.default.moveItem(at: origDir, to: renamedDir)
        XCTAssertEqual(MangaHubProjectBootstrap.resolvePrjStatus(projectDir: renamedDir.path), .renamedFolderFallback)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS2BrushStampingEngineGeneratesDeterministicStamps() {
        #if canImport(MangaCoreFFI)
        let samples = [
            NativeStrokeSample(x: 0, y: 0, pressure: 0.3, altitude: 1.3, azimuth: 0, rollAngle: 0.1, timestampMs: 1, isPredicted: false),
            NativeStrokeSample(x: 120, y: 40, pressure: 0.9, altitude: 1.2, azimuth: 0, rollAngle: 0.4, timestampMs: 9, isPredicted: false),
        ]
        let count1 = MangaBrushDynamics.generateStampCount(presetCode: 0, samples: samples)
        let count2 = MangaBrushDynamics.generateStampCount(presetCode: 0, samples: samples)
        XCTAssertGreaterThan(count1, 10)
        XCTAssertEqual(count1, count2, "Brush stamping must be 100% deterministic for replay")
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS3AtomicProseSaveAndLockedHumanGuard() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioNovelAtomic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rel = "chapters/ch001/novel/prose/zh-Hans.md"
        XCTAssertTrue(MangaNovelMetrics.saveProseAtomic(projectDir: root.path, relPath: rel, markdown: "# 终稿", isLocked: false, explicitHumanEdit: true))
        XCTAssertFalse(MangaNovelMetrics.saveProseAtomic(projectDir: root.path, relPath: rel, markdown: "AI overwrite", isLocked: true, explicitHumanEdit: false))
        XCTAssertTrue(MangaNovelMetrics.saveProseAtomic(projectDir: root.path, relPath: rel, markdown: "# 人工解锁修订", isLocked: true, explicitHumanEdit: true))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT02S4TriApp100RoundConcurrencySoakGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT02S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(MangaHubProjectBootstrap.initProject(parentDir: root.path, folderName: "T02S4Work", author: "M5Pro"))
        let projectDir = root.appendingPathComponent("T02S4Work")
        XCTAssertTrue(MangaSuiteS4Gate.run(projectDir: projectDir.path, soakRounds: 100))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
