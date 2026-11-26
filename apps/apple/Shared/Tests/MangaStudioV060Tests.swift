import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.6.0` + `T0.6-S4`**:
/// - `S2 v0.6` Track A: Diagonal B4 panel slicing + all 4 procedural halftone screentone patterns.
/// - `S2 v0.6` Track B: Webtoon vertical strip slicing (`12800px / 1280px = 10 slices`).
/// - `S3 v0.6`: EPUB3 XHTML chapter export rendering.
/// - `T0.6-S4`: Full Dual-Track Panels/Screentones/Webtoon + 5-Locale Bubbles + EPUB3 Gate on Apple Silicon.
final class MangaStudioV060Tests: XCTestCase {

    func testS2DiagonalPanelsScreentonesAndWebtoonSlicingViaCAbi() {
        #if canImport(MangaCoreFFI)
        guard let project = MangaProjectEngine(preset: .b4PrintManga600Dpi) else {
            return XCTFail("Failed to create MangaProjectEngine")
        }
        XCTAssertEqual(project.panelCount, 1)
        let afterCut = project.slicePanel(panelId: 1, from: (0, 3000), to: (6071, 5000), gutterPx: 40)
        XCTAssertEqual(afterCut, 2)

        // All 4 procedural screentone patterns produce balanced halftone dots
        for pat: UInt32 in 0...3 {
            var inked = 0
            for y: UInt32 in 0..<20 {
                for x: UInt32 in 0..<20 {
                    if MangaPublishingTools.sampleScreentoneMask(patternCode: pat, x: x, y: y) {
                        inked += 1
                    }
                }
            }
            XCTAssertGreaterThan(inked, 0)
            XCTAssertLessThan(inked, 400)
        }

        XCTAssertEqual(MangaPublishingTools.webtoonSliceCount(canvasHeight: 12800, sliceHeight: 1280), 10)
        XCTAssertEqual(MangaPublishingTools.webtoonSliceCount(canvasHeight: 3000, sliceHeight: 1280), 3)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS3NovelEpubXhtmlExportRendersValidStructure() {
        #if canImport(MangaCoreFFI)
        let xhtml = MangaPublishingTools.renderEpubXhtml(
            title: "Ch.001 Starlight Awakening",
            locale: "zh-Hans",
            markdown: "# 第一话 星辉觉醒\n\n夜风掠过屋顶，林晓握紧星纹钢笔。"
        )
        XCTAssertTrue(xhtml.contains("http://www.w3.org/1999/xhtml"))
        XCTAssertTrue(xhtml.contains("<h1>第一话 星辉觉醒</h1>"))
        XCTAssertTrue(xhtml.contains("<p>夜风掠过屋顶，林晓握紧星纹钢笔。</p>"))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT06S4FullDualTrackPublishGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT06S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T06S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T06S4MacVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT06S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
