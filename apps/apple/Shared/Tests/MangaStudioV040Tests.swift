import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.4.0` + `T0.4-S4`**:
/// - `S1 v0.4`: Canonical CPFF asset & prose ingest normalization + collision auto-versioning + AI/human isolation.
/// - `S2 v0.4`: Lasso polygon selection mask (expand/contract/invert) & Close-Gap anti-halo fill parameters.
/// - `S3 v0.4`: `<DivergenceNote>` atomic persistence & reload in `chapters/<ch>/novel/novel_meta.xml`.
/// - `T0.4-S4`: End-to-end Tri-App Integration Gate on Apple Silicon.
final class MangaStudioV040Tests: XCTestCase {

    func testS1IngestNormalizerAutoVersionsCollisionsAndIsolatesProse() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV040Ingest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let p1 = MangaHubIngest.ingestTextAsset(
            projectDir: root.path,
            chapterId: "ch001",
            kind: .referenceArt,
            filename: "Hero Sheet (Final).txt",
            payload: "v1"
        )
        let p2 = MangaHubIngest.ingestTextAsset(
            projectDir: root.path,
            chapterId: "ch001",
            kind: .referenceArt,
            filename: "Hero Sheet (Final).txt",
            payload: "v2"
        )
        XCTAssertEqual(p1, "assets/refs/Hero_Sheet__Final_.txt")
        XCTAssertEqual(p2, "assets/refs/Hero_Sheet__Final_-v2.txt")

        let prosePath = MangaHubIngest.ingestTextAsset(
            projectDir: root.path,
            chapterId: "ch001",
            kind: .proseStagingDraft,
            filename: "import_ep1.md",
            payload: "# Draft"
        )
        XCTAssertTrue(prosePath?.hasPrefix("chapters/ch001/ai_assist/ingest_staging/") ?? false)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS2LassoSelectionExpandAndInvertAndS3DivergenceNoteRoundTrip() throws {
        #if canImport(MangaCoreFFI)
        let xs: [Float] = [10, 40, 40, 10]
        let ys: [Float] = [10, 10, 40, 40]
        let baseCount = MangaSelectionEngine.lassoPixelCount(xs: xs, ys: ys, width: 80, height: 80, invert: false, borderDeltaPx: 0)
        let expandedCount = MangaSelectionEngine.lassoPixelCount(xs: xs, ys: ys, width: 80, height: 80, invert: false, borderDeltaPx: 1)
        let invertedCount = MangaSelectionEngine.lassoPixelCount(xs: xs, ys: ys, width: 80, height: 80, invert: true, borderDeltaPx: 0)

        XCTAssertEqual(baseCount, 900)
        XCTAssertEqual(expandedCount, 1024)
        XCTAssertEqual(invertedCount, 80 * 80 - 900)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV040Div-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(
            MangaNovelMetrics.addDivergenceNote(
                projectDir: root.path,
                chapterId: "ch001",
                sceneId: "sc003",
                summary: "Novel deepens rooftop monologue while manga focuses on wide atmospheric spread."
            )
        )
        let notes = MangaNovelMetrics.readDivergenceNotes(projectDir: root.path, chapterId: "ch001")
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].sceneId, "sc003")
        XCTAssertTrue(notes[0].summary.contains("rooftop monologue"))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT04S4FullTriAppIngestFillAndDivergenceGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT04S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T04S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T04S4MacVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT04S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
