import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.3.2` + `T0.3-S4`**:
/// - `S1/S3 v0.3.2`: Live structured Story Bible & Master TOC read/write round-trip across C-ABI (`< 300ms` SLA).
/// - `S2 v0.3.2`: All 13 cel-shading `LayerBlendMode` values map cleanly to SwiftUI compositing modes + display names.
/// - `T0.3-S4`: Full Tri-App Story Bible Hot-Reload + 13 Cel Blend Modes + `R`/`✂`/`🔒`/`B` Integration Gate on macOS.
final class MangaStudioV032Tests: XCTestCase {

    func testS1AndS3LiveStoryBibleAndTocSummaryRoundTripUnder300ms() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV032-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rev0 = MangaStoryBible.revisionHash(projectDir: root.path)
        XCTAssertTrue(
            MangaStoryBible.upsertCharacter(
                projectDir: root.path,
                id: "char-sora",
                nameZh: "苍月",
                nameEn: "Sora Tsuki",
                role: "mentor",
                paletteHex: "#2FA88B"
            )
        )
        XCTAssertTrue(
            MangaStoryBible.upsertTocEntry(
                projectDir: root.path,
                chapterId: "ch003",
                number: 3,
                titleZh: "双生分镜",
                titleEn: "Twin Storyboards",
                status: "draft"
            )
        )

        let t0 = Date()
        let rev1 = MangaStoryBible.revisionHash(projectDir: root.path)
        let chars = MangaStoryBible.readCharacters(projectDir: root.path)
        let toc = MangaStoryBible.readTocEntries(projectDir: root.path)
        let elapsedMs = Date().timeIntervalSince(t0) * 1000.0

        XCTAssertNotEqual(rev0, rev1)
        XCTAssertEqual(chars.count, 1)
        XCTAssertEqual(chars[0].nameZh, "苍月")
        XCTAssertEqual(chars[0].nameEn, "Sora Tsuki")
        XCTAssertEqual(toc.count, 1)
        XCTAssertEqual(toc[0].id, "ch003")
        XCTAssertEqual(toc[0].number, 3)
        XCTAssertLessThan(elapsedMs, 300.0, "S3 read-only reload of Story Bible + TOC must stay under 300ms")
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT03S4FullTriAppBibleAnd13CelBlendModesGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT03S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T03S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T03S4MacVerify").path

        let t0 = Date()
        let passed = MangaSuiteS4Gate.runT03S4(projectDir: projectDir)
        let elapsedMs = Date().timeIntervalSince(t0) * 1000.0

        XCTAssertTrue(passed, "T0.3-S4 Tri-App Story Bible & 13-Mode Cel Gate must pass on Apple Silicon")
        XCTAssertLessThan(elapsedMs, 300.0)
        XCTAssertEqual(MangaStoryBible.readCharacters(projectDir: projectDir).count, 3)
        XCTAssertEqual(MangaStoryBible.readTocEntries(projectDir: projectDir).count, 3)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS2AllThirteenBlendModesMapCleanlyToLiveCanvasCompositing() {
        XCTAssertGreaterThanOrEqual(LayerBlendMode.allCases.count, 13)
        for mode in LayerBlendMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            #if canImport(SwiftUI)
            _ = mode.swiftUIBlendMode
            #endif
        }
    }
}
