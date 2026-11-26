import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.9.0` + `T0.9-S4` (Wave 1 Joint Beta)**:
/// - Track A: 50-step CoW Undo/Redo benchmark on B4 600DPI (`6071×8598`) sparse tile layer under `< 16ms/step` SLA.
/// - Track B + 8GB Guard: High-res `1600×25600` Webtoon slicing & combined Tri-App RAM budget (`<= 2048 MB`).
/// - Full `T0.9-S4` Pre-1.0 Apple Wave 1 Joint Beta Stress Gate on Apple Silicon.
final class MangaStudioV090Tests: XCTestCase {

    func testB4FiftyStepCowUndoBenchmarkStaysWellUnder16MsSlaOnAppleSilicon() {
        #if canImport(MangaCoreFFI)
        let elapsedUs = MangaBetaStressBench.runB4FiftyStepCowUndoBenchmarkUs()
        XCTAssertGreaterThan(elapsedUs, 0)
        // 50 steps * 16ms/step = 800,000 us ceiling; M5 Pro completes in a few milliseconds
        XCTAssertLessThan(elapsedUs, 800_000)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testWave1AppleTrioCombinedRamBudgetAndWebtoon1600Slicing() {
        #if canImport(MangaCoreFFI)
        let combined = MangaSuitePolicy.ramBudgetMb(for: .hub)
            + MangaSuitePolicy.ramBudgetMb(for: .manga)
            + MangaSuitePolicy.ramBudgetMb(for: .novel)
        XCTAssertEqual(combined, 1856)
        XCTAssertLessThanOrEqual(combined, 2048)

        // High-res Webtoon 1600x25600 @ 1280px = 20 seamless slices
        XCTAssertEqual(MangaPublishingTools.webtoonSliceCount(canvasHeight: 25600, sliceHeight: 1280), 20)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT09S4FullWave1JointBetaStressGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT09S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T09S4MacBetaVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T09S4MacBetaVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT09S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
