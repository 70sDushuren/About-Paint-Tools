import Foundation
import XCTest

/// Live M5 Pro Apple Silicon Swift ↔ Rust `MangaCoreFFI` verification suite for **`v0.8.0` + `T0.8-S4`**:
/// - Multi-touch Undo/Redo, Apple Pencil Pro Squeeze Radial Menu & Palm Rejection via C-ABI.
/// - iPhone Duo unfolded hinge-safe pane width calculation.
/// - Live 5-language runtime catalog (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).
/// - Full `T0.8-S4` Apple Trio Ergonomics & 5-i18n Gate on Apple Silicon.
final class MangaStudioV080Tests: XCTestCase {

    func testAppleTrioGesturesAndIphoneDuoHingeGeometryViaCAbi() {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(
            MangaErgonomicsEngine.resolveGesture(
                touchCount: 2, durationMs: 110, maxTravelPx: 4, contactRadiusPx: 6,
                stylusActive: false, pencilSqueeze: false
            ),
            .undo
        )
        XCTAssertEqual(
            MangaErgonomicsEngine.resolveGesture(
                touchCount: 3, durationMs: 130, maxTravelPx: 5, contactRadiusPx: 6,
                stylusActive: false, pencilSqueeze: false
            ),
            .redo
        )
        XCTAssertEqual(
            MangaErgonomicsEngine.resolveGesture(
                touchCount: 0, durationMs: 0, maxTravelPx: 0, contactRadiusPx: 0,
                stylusActive: true, pencilSqueeze: true
            ),
            .toggleRadialMenu
        )
        XCTAssertEqual(
            MangaErgonomicsEngine.resolveGesture(
                touchCount: 1, durationMs: 40, maxTravelPx: 2, contactRadiusPx: 24,
                stylusActive: true, pencilSqueeze: false
            ),
            .rejectPalm
        )

        let panes = MangaErgonomicsEngine.computeFoldablePanes(
            viewportWidthDp: 780,
            posture: .unfoldedDualPane,
            reportedCreaseDp: 20
        )
        XCTAssertTrue(panes.isSplit)
        XCTAssertEqual(panes.hingeWidth, 20, accuracy: 0.01)
        XCTAssertEqual(panes.leftWidth, 380, accuracy: 0.01)
        XCTAssertEqual(panes.rightWidth, 380, accuracy: 0.01)
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testLiveFiveLanguageRuntimeCatalogViaCAbi() {
        #if canImport(MangaCoreFFI)
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "action.undo", locale: .en), "Undo")
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "action.undo", locale: .zhHans), "撤销")
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "action.undo", locale: .zhHant), "復原")
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "action.undo", locale: .yueHant), "還原")
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "action.undo", locale: .es), "Deshacer")
        XCTAssertEqual(MangaErgonomicsEngine.translate(key: "workspace.manga", locale: .yueHant), "漫畫工作枱")
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }

    func testT08S4FullAppleTrioErgonomicsAndI18nGateOnMacOS() throws {
        #if canImport(MangaCoreFFI)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaStudioT08S4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        XCTAssertTrue(
            MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "T08S4MacVerify",
                author: "M5ProGate"
            )
        )
        let projectDir = parent.appendingPathComponent("T08S4MacVerify").path
        XCTAssertTrue(MangaSuiteS4Gate.runT08S4(projectDir: projectDir))
        #else
        XCTFail("MangaCoreFFI required")
        #endif
    }
}
