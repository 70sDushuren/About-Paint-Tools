import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.7.0` + `T0.7-S4`**:
/// - `S2 v0.7`: Open `.mnga` atomic manuscript persistence (with FNV-1a checksum & write-ownership isolation)
///   and Adobe PSD (`8BPS` v1 RGB8) interchange export.
/// - `S3 v0.7`: Light-novel illustration slot dual policy (`PickMangaPage` vs `CustomCommissioned`).
/// - `T0.7-S4`: Full `.mnga` + PSD + `ActionBus` transactional macro + S3 illustration slot gate on Apple Silicon.
final class MangaStudioV070Tests: XCTestCase {

    func testS2MngaAtomicSaveAndPsd8BpsExportViaCAbi() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV070-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "MngaPsdVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("MngaPsdVerify").path

        guard let project = MangaProjectEngine(preset: .illustration4K) else {
            return XCTFail("Failed to create MangaProjectEngine")
        }
        _ = project.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, isReference: true)
        _ = project.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: true)

        // S2 write ownership allows chapters/*/manuscript/*.mnga
        let mngaBytes = project.saveMngaSnapshot(
            projectDir: projectDir,
            relPath: "chapters/ch001/manuscript/p001.mnga",
            dpi: 600,
            timelapseEvents: 64
        )
        XCTAssertGreaterThan(mngaBytes, 40)

        // S2 write ownership blocks writing into novel prose path
        let blockedBytes = project.saveMngaSnapshot(
            projectDir: projectDir,
            relPath: "chapters/ch001/novel/prose/zh-Hans.md",
            dpi: 600,
            timelapseEvents: 1
        )
        XCTAssertEqual(blockedBytes, 0)

        // Minimal PSD 8BPS export produces non-empty valid payload
        XCTAssertGreaterThan(project.psdExportByteLength(), 40)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS3NovelIllustrationSlotPolicyViaCAbi() {
        #if canImport(MangaCoreFFI)
        // mode 0 = PickMangaPage, mode 1 = CustomCommissioned
        XCTAssertTrue(
            MangaPersistenceTools.validateNovelIllustrationSlot(
                modeCode: 0,
                relSrc: "chapters/ch001/manuscript/p003.mnga"
            )
        )
        XCTAssertTrue(
            MangaPersistenceTools.validateNovelIllustrationSlot(
                modeCode: 1,
                relSrc: "chapters/ch001/novel/illustrations/ch001_plate01.png"
            )
        )
        XCTAssertFalse(
            MangaPersistenceTools.validateNovelIllustrationSlot(
                modeCode: 1,
                relSrc: "../escape.png"
            )
        )
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT07S4FullMngaPsdActionBusGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT07S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T07S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T07S4MacVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT07S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
