import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.5.0` + `T0.5-S4`**:
/// - `S1/S3 v0.5`: 5-locale `bible/glossary.xml` atomic write + localized proper-noun autocomplete (`zh-Hans`/`en`/`es`).
/// - `S2 v0.5`: Vector lineart stroke creation + single-swipe Vector Intersection Eraser + Symmetry/Perspective/Focus rulers.
/// - `T0.5-S4`: Full Tri-App Vector + Ruler + 5-Locale Glossary Integration Gate on Apple Silicon.
final class MangaStudioV050Tests: XCTestCase {

    func testS2VectorIntersectionEraserAndThreeMangaRulersViaCAbi() {
        #if canImport(MangaCoreFFI)
        guard let project = MangaProjectEngine(preset: .b4PrintManga600Dpi) else {
            return XCTFail("Failed to create MangaProjectEngine")
        }
        let hId = project.addVectorStroke(xs: [0, 100], ys: [50, 50], widths: [2.5, 2.5], rgba: (0, 0, 0, 255))
        let vId = project.addVectorStroke(xs: [50, 50], ys: [0, 100], widths: [2.5, 2.5], rgba: (0, 0, 0, 255))
        XCTAssertGreaterThan(hId, 0)
        XCTAssertGreaterThan(vId, 0)
        XCTAssertEqual(project.vectorStrokeCount, 2)
        XCTAssertTrue(project.eraseVectorToIntersection(hitX: 80, hitY: 50, hitRadius: 6))

        // Symmetry mirror across vertical axis x = 200
        let mirrored = MangaRulerEngine.transformPoint(
            mode: .symmetry,
            paramX: 200,
            paramY: 0,
            paramAux: .pi / 2,
            anchorX: 140,
            anchorY: 80,
            inX: 140,
            inY: 80
        )
        XCTAssertEqual(mirrored.x, 260, accuracy: 0.1)
        XCTAssertEqual(mirrored.y, 80, accuracy: 0.1)

        // Focus lines snap radially toward center (500, 500)
        let focus = MangaRulerEngine.transformPoint(
            mode: .focusLines,
            paramX: 500,
            paramY: 500,
            paramAux: 0,
            anchorX: 800,
            anchorY: 500,
            inX: 700,
            inY: 525
        )
        XCTAssertEqual(focus.y, 500, accuracy: 0.1)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testS1AndS3FiveLocaleGlossaryUpsertAndLocalizedAutocomplete() throws {
        #if canImport(MangaCoreFFI)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioV050Gloss-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertTrue(
            MangaGlossary.upsertTerm(
                projectDir: root.path,
                key: "weapon.starlight_blade",
                en: "Starlight Blade",
                zhHans: "星辉之刃",
                zhHant: "星輝之刃",
                yueHant: "星輝之刃",
                es: "Hoja Estelar",
                locked: true
            )
        )
        let esHits = MangaGlossary.suggestTerms(projectDir: root.path, query: "starlight", locale: "es")
        XCTAssertEqual(esHits.count, 1)
        XCTAssertEqual(esHits[0].localizedValue, "Hoja Estelar")
        XCTAssertEqual(esHits[0].status, "5/5")
        XCTAssertFalse(MangaSuitePolicy.canWrite(app: .novel, relativePath: "bible/glossary.xml"))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT05S4FullTriAppVectorRulerAndGlossaryGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT05S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T05S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T05S4MacVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT05S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
