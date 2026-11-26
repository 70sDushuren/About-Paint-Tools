import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v1.0.0-rc1` + `T1.0-S4`**:
/// - Local Apache-2.0 Gemma 4 model pack selector (`E2B` for 8GB, `E4B` for 16GB+).
/// - Bidirectional `Manga -> Novel` & `Novel -> Manga` AI reference bridge strictly isolated inside `ai_assist/`.
/// - Byte-immutability audit confirming human finals (`novel/prose/zh-Hans.md`) are NEVER overwritten.
/// - Full `T1.0-S4` Wave 1 Release Candidate Gate on Apple Silicon.
final class MangaStudioV100Tests: XCTestCase {

    func testGemma4LocalModelPackRecommendationMatchesDeviceRamPolicy() {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(MangaGemmaAiBridge.recommendPack(deviceRamGb: 8), .gemma4E2b)
        XCTAssertEqual(MangaGemmaAiBridge.recommendPack(deviceRamGb: 12), .gemma4E2b)
        XCTAssertEqual(MangaGemmaAiBridge.recommendPack(deviceRamGb: 16), .gemma4E4b)
        XCTAssertEqual(MangaGemmaAiBridge.recommendPack(deviceRamGb: 36), .gemma4E4b)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testBidirectionalGemma4BridgeStaysInsideAiAssistAndPreservesHumanFinals() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV100-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "Gemma4BridgeVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("Gemma4BridgeVerify").path
        let humanProsePath = parent
            .appendingPathComponent("Gemma4BridgeVerify/chapters/ch001/novel/prose/zh-Hans.md")
        let beforeData = try Data(contentsOf: humanProsePath)

        let m2nRel = MangaGemmaAiBridge.generateMangaToNovelRef(
            projectDir: projectDir,
            chapterId: "ch001",
            locale: "zh-Hans",
            beatSummary: "Panel 1: Rooftop wind storm; Panel 2: Starlight Blade glows.",
            pack: .gemma4E2b
        )
        XCTAssertEqual(m2nRel, "ai_assist/manga_to_novel/ai_prose_ref_zh-Hans.md")

        let n2mRel = MangaGemmaAiBridge.generateNovelToMangaRef(
            projectDir: projectDir,
            chapterId: "ch001",
            proseExcerpt: "夜风掠过屋顶，林晓握紧星纹钢笔。",
            pack: .gemma4E4b
        )
        XCTAssertEqual(n2mRel, "ai_assist/novel_to_manga/ai_storyboard_ref.xml")

        // Human authoritative prose must remain byte-for-byte identical
        let afterData = try Data(contentsOf: humanProsePath)
        XCTAssertEqual(beforeData, afterData)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT10S4FullWave1ReleaseCandidateGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT10S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T10S4MacRc1Verify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T10S4MacRc1Verify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT10S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
