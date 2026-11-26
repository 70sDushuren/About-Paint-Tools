import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.3.1`**:
/// - `S1 v0.3.1`: Story Bible (`bible/characters.xml`) atomic upsert & `< 300ms` cross-app revision hash.
/// - `S2 v0.3.1`: 13 cel-shading blend modes & layer drawer flags (`R` / `✂` / `🔒` / `B`) via `MangaProjectEngine`.
/// - `S3 v0.3.1`: Read-only Story Bible access & strict write-ownership isolation blocking S2/S3 from `bible/` and `outline/`.
final class MangaStudioV031Tests: XCTestCase {

    func testS1StoryBibleAtomicUpsertAndHotReloadRevisionHash() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioBible-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rev0 = MangaStoryBible.revisionHash(projectDir: root.path)
        XCTAssertEqual(MangaStoryBible.characterCount(projectDir: root.path), 0)

        let t0 = Date()
        XCTAssertTrue(
            MangaStoryBible.upsertCharacter(
                projectDir: root.path,
                id: "char-lin",
                nameZh: "林晓",
                nameEn: "Lin Xiao",
                role: "protagonist",
                paletteHex: "#4F7CFF"
            )
        )
        let rev1 = MangaStoryBible.revisionHash(projectDir: root.path)
        let elapsedMs = Date().timeIntervalSince(t0) * 1000.0

        XCTAssertNotEqual(rev0, rev1, "Revision hash must change immediately after S1 atomic upsert")
        XCTAssertEqual(MangaStoryBible.characterCount(projectDir: root.path), 1)
        XCTAssertLessThan(elapsedMs, 300.0, "Cross-app Story Bible hot-reload must stay well under 300ms SLA")

        // Second character upsert updates count cleanly
        XCTAssertTrue(
            MangaStoryBible.upsertCharacter(
                projectDir: root.path,
                id: "char-ren",
                nameZh: "墨凛",
                nameEn: "Mo Lin",
                role: "rival",
                paletteHex: "#FF6B4A"
            )
        )
        XCTAssertEqual(MangaStoryBible.characterCount(projectDir: root.path), 2)
        XCTAssertNotEqual(rev1, MangaStoryBible.revisionHash(projectDir: root.path))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS2ThirteenBlendModesAndLayerDrawerFlagsViaProjectEngine() {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(LayerBlendMode.allCases.count, 13, "S2 v0.3.1 requires all 13 cel-shading blend modes")
        guard let project = MangaProjectEngine(preset: .b4PrintManga600Dpi) else {
            return XCTFail("Failed to create MangaProjectEngine")
        }

        let lineartId = project.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, clippingMask: false, isReference: true)
        let shadowId = project.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: true, isReference: false)
        let sketchId = project.addRasterLayer(name: "Sketch_Rough", blendMode: .normal, clippingMask: false, isReference: false)

        XCTAssertGreaterThan(lineartId, 0)
        XCTAssertGreaterThan(shadowId, 0)
        XCTAssertGreaterThan(sketchId, 0)
        XCTAssertEqual(project.layerCount, 3)

        // Toggle R / ✂ / 🔒 / B flags across all 3 layers via live C-ABI
        XCTAssertTrue(project.setLayerFlags(layerId: lineartId, visible: true, alphaLock: true, clippingMask: false, isReference: true, blendMode: .normal, opacity: 1.0, blueSketchTint: false))
        XCTAssertTrue(project.setLayerFlags(layerId: shadowId, visible: true, alphaLock: false, clippingMask: true, isReference: false, blendMode: .glowDodge, opacity: 0.72, blueSketchTint: false))
        XCTAssertTrue(project.setLayerFlags(layerId: sketchId, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .multiply, opacity: 0.35, blueSketchTint: true))

        // Invalid layer id returns false cleanly
        XCTAssertFalse(project.setLayerFlags(layerId: 999_999, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .normal, opacity: 1.0, blueSketchTint: false))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS3StoryBibleAndTocWriteOwnershipBlockedForNovelAndManga() {
        #if canImport(MangaCoreFFI)
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .hub, relativePath: "bible/characters.xml"))
        XCTAssertTrue(MangaSuitePolicy.canWrite(app: .hub, relativePath: "outline/toc.xml"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .manga, relativePath: "bible/characters.xml"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .novel, relativePath: "bible/characters.xml"))
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .novel, relativePath: "outline/toc.xml"))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
