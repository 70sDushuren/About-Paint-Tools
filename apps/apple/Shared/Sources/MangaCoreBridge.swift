import Foundation

/// Hardware-native stylus/touch sample mirrored 1:1 with `manga_core::StrokePoint`
/// and shared across iPadOS (UIKit), macOS Touch (AppKit), and iPhone Duo.
public struct NativeStrokeSample: Sendable {
    public let x: Float
    public let y: Float
    public let pressure: Float
    public let altitude: Float
    public let azimuth: Float
    public let rollAngle: Float
    public let timestampMs: Double
    public let isPredicted: Bool

    public init(
        x: Float,
        y: Float,
        pressure: Float,
        altitude: Float,
        azimuth: Float,
        rollAngle: Float,
        timestampMs: Double,
        isPredicted: Bool
    ) {
        self.x = x
        self.y = y
        self.pressure = pressure
        self.altitude = altitude
        self.azimuth = azimuth
        self.rollAngle = rollAngle
        self.timestampMs = timestampMs
        self.isPredicted = isPredicted
    }
}

/// Swift-side mirror of `MangaCanvasPreset` in `core/manga-core/include/manga_core.h`.
public enum CanvasPresetKind: UInt32, CaseIterable, Sendable {
    case b4PrintManga600Dpi = 0
    case a4PrintManga600Dpi = 1
    case webtoonStrip800 = 2
    case webtoonStrip1600 = 3
    case illustration4K = 4
}

/// Swift-side mirror of `MangaBlendMode` in `core/manga-core/include/manga_core.h`.
public enum LayerBlendMode: UInt32, CaseIterable, Sendable {
    case normal = 0
    case multiply = 1
    case screen = 2
    case overlay = 3
    case glowDodge = 4
    case linearBurn = 5
    case hardLight = 6
    case softLight = 7
    case darken = 8
    case lighten = 9
    case colorBurn = 10
    case colorDodge = 11
    case add = 12

    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .glowDodge: return "Glow Dodge"
        case .linearBurn: return "Linear Burn"
        case .hardLight: return "Hard Light"
        case .softLight: return "Soft Light"
        case .darken: return "Darken"
        case .lighten: return "Lighten"
        case .colorBurn: return "Color Burn"
        case .colorDodge: return "Color Dodge"
        case .add: return "Add (Glow)"
        }
    }
}

/// `v0.8` — Supported 5-language live runtime locales (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`).
public enum UiLocaleKind: UInt32, CaseIterable, Sendable, Identifiable {
    case en = 0
    case zhHans = 1
    case zhHant = 2
    case yueHant = 3
    case es = 4

    public var id: UInt32 { rawValue }

    public var bcp47: String {
        switch self {
        case .en: return "en"
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .yueHant: return "yue-Hant"
        case .es: return "es"
        }
    }

    public var shortBadge: String {
        switch self {
        case .en: return "EN"
        case .zhHans: return "简中"
        case .zhHant: return "繁中"
        case .yueHant: return "粵語"
        case .es: return "ES"
        }
    }

    public var nativeLabel: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .yueHant: return "廣東話"
        case .es: return "Español"
        }
    }
}

/// `v0.8` — Deterministic touch & stylus gesture actions mirrored from `gesture.rs`.
public enum GestureActionKind: UInt32, Sendable {
    case none = 0
    case undo = 1
    case redo = 2
    case toggleRadialMenu = 3
    case rejectPalm = 4
    case panZoomCanvas = 5
}

/// `v1.0` — Local Apache-2.0 Gemma 4 model packs (`E2B` for 8GB, `E4B` for 16GB+).
public enum GemmaModelPackKind: UInt32, Sendable {
    case gemma4E2b = 0
    case gemma4E4b = 1
}

/// Swift-side mirror of `MangaTargetPlatform` in `manga_core.h`.
public enum TargetPlatformKind: UInt32, CaseIterable, Sendable {
    case ipadOs = 0
    case macOsTouch = 1
    case iphoneDuo = 2
    case androidPadFoldable = 3
    case windowsTouch = 4
    case linuxTouch = 5
}

/// Swift-side mirror of `MangaFoldPosture` in `manga_core.h`.
public enum FoldPostureKind: UInt32, CaseIterable, Sendable {
    case flat = 0
    case foldedCompact = 1
    case unfoldedDualPane = 2
    case tabletopHalfOpen = 3
    case convertibleTabletMode = 4
}

/// Swift-side mirror of `MangaWorkspaceLayout` in `manga_core.h`.
public enum WorkspaceLayoutHintKind: UInt32, CaseIterable, Sendable {
    case singlePaneCompact = 0
    case tabletTouchStudio = 1
    case dualPaneAcrossHinge = 2
    case tabletopCanvasTopControlsBottom = 3
    case desktopTouchHybrid = 4
}

/// Swift-side mirror of `MangaSuiteApp` in `manga_core.h`.
/// Chinese/English/Spanish tool names are working codenames pending final pre-release branding.
public enum SuiteAppKind: UInt32, CaseIterable, Sendable {
    /// Working codename: 创想空间 / NoemaDock (Project Hub & Multi-Language Publishing)
    case hub = 0
    /// Working codename: 雕龙 / DracoNib (Manga & Illustration Drawing)
    case manga = 1
    /// Working codename: 文心 / LitteraCore (Light Novel Authoring & Publishing)
    case novel = 2
}

/// Read-only Story Bible character projection (`bible/characters.xml`) shared across S1/S2/S3.
public struct StoryBibleCharacterSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let nameZh: String
    public let nameEn: String
    public let role: String
    public let paletteHex: String

    public init(id: String, nameZh: String, nameEn: String, role: String, paletteHex: String) {
        self.id = id
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.role = role
        self.paletteHex = paletteHex
    }
}

/// Read-only Master TOC chapter projection (`outline/toc.xml`) shared across S1/S2/S3.
public struct ProjectTocEntrySummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let number: UInt32
    public let titleZh: String
    public let titleEn: String
    public let status: String

    public init(id: String, number: UInt32, titleZh: String, titleEn: String, status: String) {
        self.id = id
        self.number = number
        self.titleZh = titleZh
        self.titleEn = titleEn
        self.status = status
    }
}

/// Intentional Manga ↔ Novel adaptation note persisted in `chapters/<ch>/novel/novel_meta.xml` (`S3 v0.4`).
public struct DivergenceNoteSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let sceneId: String
    public let summary: String

    public init(id: String = UUID().uuidString, sceneId: String, summary: String) {
        self.id = id
        self.sceneId = sceneId
        self.summary = summary
    }
}

/// Canonical asset ingest routing category (`S1 v0.4`).
public enum IngestAssetKindBridge: UInt32, CaseIterable, Sendable, Identifiable {
    case referenceArt = 0
    case proseStagingDraft = 1
    case storyboardScan = 2

    public var id: UInt32 { rawValue }
    public var displayName: String {
        switch self {
        case .referenceArt: return "Reference Art (assets/refs/)"
        case .proseStagingDraft: return "Prose Staging (ai_assist/ingest_staging/)"
        case .storyboardScan: return "Storyboard Scan (assets/ingest/)"
        }
    }
}

/// 5-language canonical glossary suggestion projected from `bible/glossary.xml` (`S1`/`S3 v0.5`).
public struct GlossaryTermSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let localizedValue: String
    public let en: String
    public let zhHans: String
    public let status: String

    public init(id: String, localizedValue: String, en: String, zhHans: String, status: String) {
        self.id = id
        self.localizedValue = localizedValue
        self.en = en
        self.zhHans = zhHans
        self.status = status
    }
}

/// Active manga drawing ruler mode (`S2 v0.5`).
public enum RulerModeKind: UInt32, CaseIterable, Sendable, Identifiable {
    case off = 99
    case symmetry = 0
    case parallel = 1
    case perspective2Pt = 2
    case focusLines = 3

    public var id: UInt32 { rawValue }
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .symmetry: return "Symmetry"
        case .parallel: return "Parallel"
        case .perspective2Pt: return "2-Pt Persp"
        case .focusLines: return "Focus Lines"
        }
    }
}

/// Shared on-disk `.prj` sandbox workspace so `S1` (Hub), `S2` (Manga), and `S3` (Novel)
/// demonstrate live `< 300ms` cross-app hot-reload immediately on launch.
public enum SuiteSharedWorkspace {
    public static var defaultProjectDir: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("AboutPaintTools", isDirectory: true)
            .appendingPathComponent("DefaultWorkspace", isDirectory: true)
            .appendingPathComponent("StarlightLive", isDirectory: true)
            .path
    }

    public static func bootstrapDefaultWorkspaceIfNeeded() -> String {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("AboutPaintLiveWorkspace", isDirectory: true)
        let projectDir = parent.appendingPathComponent("StarlightLive", isDirectory: true).path
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        #if canImport(MangaCoreFFI)
        if MangaHubProjectBootstrap.resolvePrjStatus(projectDir: projectDir) == .invalid {
            _ = MangaHubProjectBootstrap.initProject(
                parentDir: parent.path,
                folderName: "StarlightLive",
                author: "Studio Creator"
            )
        }
        if MangaStoryBible.characterCount(projectDir: projectDir) == 0 {
            _ = MangaStoryBible.upsertCharacter(
                projectDir: projectDir,
                id: "char-lin",
                nameZh: "林晓",
                nameEn: "Lin Xiao",
                role: "protagonist",
                paletteHex: "#4F7CFF"
            )
            _ = MangaStoryBible.upsertCharacter(
                projectDir: projectDir,
                id: "char-ren",
                nameZh: "墨凛",
                nameEn: "Mo Lin",
                role: "rival",
                paletteHex: "#FF6B4A"
            )
        }
        if MangaStoryBible.readTocEntries(projectDir: projectDir).isEmpty {
            _ = MangaStoryBible.upsertTocEntry(
                projectDir: projectDir,
                chapterId: "ch001",
                number: 1,
                titleZh: "星辉觉醒",
                titleEn: "Starlight Awakening",
                status: "in_progress"
            )
            _ = MangaStoryBible.upsertTocEntry(
                projectDir: projectDir,
                chapterId: "ch002",
                number: 2,
                titleZh: "墨影回廊",
                titleEn: "Ink Shadow Corridor",
                status: "draft"
            )
        }
        #endif
        return projectDir
    }
}

#if canImport(MangaCoreFFI)
import MangaCoreFFI

/// Queries Rust `manga-core` for deterministic cross-platform layout decisions.
public enum MangaPlatformLayoutEngine {
    public static func recommendLayout(
        platform: TargetPlatformKind,
        posture: FoldPostureKind,
        widthDp: Float,
        heightDp: Float
    ) -> WorkspaceLayoutHintKind {
        let code = manga_platform_recommend_layout(
            platform.rawValue,
            posture.rawValue,
            widthDp,
            heightDp
        )
        return WorkspaceLayoutHintKind(rawValue: code) ?? .tabletTouchStudio
    }
}

/// Queries Rust `manga-core` (`suite.rs`) for Tri-App write-ownership isolation and RAM budgets.
public enum MangaSuitePolicy {
    public static let isRustFfiLinked: Bool = true

    public static func canWrite(app: SuiteAppKind, relativePath: String) -> Bool {
        relativePath.withCString { cPath in
            manga_suite_can_write_path(app.rawValue, cPath) != 0
        }
    }

    public static func ramBudgetMb(for app: SuiteAppKind) -> UInt32 {
        manga_suite_ram_budget_mb(app.rawValue)
    }
}

/// `S1 v0.2.3` — CPFF `.prj` resolution result mirrored from `MangaPrjResolutionStatus`.
public enum PrjResolutionKind: UInt32, Sendable {
    case invalid = 0
    case exactMatch = 1
    case renamedFolderFallback = 2
}

/// `S1 v0.2.1–v0.2.3` — Bootstraps & inspects CPFF v1.0 dual-engine `.prj` folders via Rust `manga-core`.
public enum MangaHubProjectBootstrap {
    @discardableResult
    public static func initProject(parentDir: String, folderName: String, author: String) -> Bool {
        parentDir.withCString { cParent in
            folderName.withCString { cFolder in
                author.withCString { cAuthor in
                    manga_hub_init_project(cParent, cFolder, cAuthor) != 0
                }
            }
        }
    }

    public static func resolvePrjStatus(projectDir: String) -> PrjResolutionKind {
        let code = projectDir.withCString { cDir in
            manga_hub_resolve_prj_status(cDir)
        }
        return PrjResolutionKind(rawValue: code) ?? .invalid
    }
}

/// `S2 v0.2.1–v0.2.3` — Deterministic anime brush dynamics, stamping engine & zoom-adaptive Rope Stabilizer.
public enum MangaBrushDynamics {
    public static var presetCount: UInt32 { manga_brush_preset_count() }

    public static func sampleRadius(presetCode: UInt32, pressure: Float, altitude: Float) -> Float {
        manga_brush_sample_radius(presetCode, pressure, altitude)
    }

    public static func zoomAdaptiveRope(baseScreenPx: Float, viewportZoom: Float) -> Float {
        manga_brush_zoom_adaptive_rope(baseScreenPx, viewportZoom)
    }

    public static func generateStampCount(presetCode: UInt32, samples: [NativeStrokeSample]) -> Int {
        guard !samples.isEmpty else { return 0 }
        let cPoints = samples.map { s in
            CMangaStrokePoint(
                x: s.x,
                y: s.y,
                pressure: s.pressure,
                altitude: s.altitude,
                azimuth: s.azimuth,
                roll_angle: s.rollAngle,
                timestamp_ms: s.timestampMs,
                is_predicted: s.isPredicted ? 1 : 0
            )
        }
        return cPoints.withUnsafeBufferPointer { buf in
            Int(manga_brush_generate_stamp_count(presetCode, buf.baseAddress, buf.count))
        }
    }
}

/// `S3 v0.2.1–v0.2.3` — Mixed CJK + Latin publishing unit counter & atomic prose storage with `locked="true"` guard.
public enum MangaNovelMetrics {
    public static func countUnits(in text: String) -> Int {
        text.withCString { cText in
            Int(manga_novel_count_units(cText))
        }
    }

    @discardableResult
    public static func saveProseAtomic(
        projectDir: String,
        relPath: String,
        markdown: String,
        isLocked: Bool,
        explicitHumanEdit: Bool
    ) -> Bool {
        projectDir.withCString { cDir in
            relPath.withCString { cRel in
                markdown.withCString { cBody in
                    manga_novel_save_prose_atomic(
                        cDir,
                        cRel,
                        cBody,
                        isLocked ? 1 : 0,
                        explicitHumanEdit ? 1 : 0
                    ) != 0
                }
            }
        }
    }

    @discardableResult
    public static func addDivergenceNote(
        projectDir: String,
        chapterId: String,
        sceneId: String,
        summary: String
    ) -> Bool {
        projectDir.withCString { cDir in
            chapterId.withCString { cCh in
                sceneId.withCString { cScene in
                    summary.withCString { cSummary in
                        manga_novel_add_divergence_note(cDir, cCh, cScene, cSummary) != 0
                    }
                }
            }
        }
    }

    public static func readDivergenceNotes(projectDir: String, chapterId: String) -> [DivergenceNoteSummary] {
        var buffer = [CChar](repeating: 0, count: 16_384)
        let written = projectDir.withCString { cDir in
            chapterId.withCString { cCh in
                buffer.withUnsafeMutableBufferPointer { buf in
                    manga_novel_read_divergence_notes(cDir, cCh, buf.baseAddress, buf.count)
                }
            }
        }
        guard written > 0 else { return [] }
        let raw = String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return raw.split(separator: "\n", omittingEmptySubsequences: true).enumerated().compactMap { idx, line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2 else { return nil }
            return DivergenceNoteSummary(id: "\(chapterId)-\(idx)", sceneId: parts[0], summary: parts[1])
        }
    }
}

/// `S1 v0.4` — Canonical CPFF asset & prose ingest normalizer with collision protection & AI/human isolation.
public enum MangaHubIngest {
    public static func ingestTextAsset(
        projectDir: String,
        chapterId: String,
        kind: IngestAssetKindBridge,
        filename: String,
        payload: String
    ) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let written = projectDir.withCString { cDir in
            chapterId.withCString { cCh in
                filename.withCString { cFile in
                    payload.withCString { cPayload in
                        buffer.withUnsafeMutableBufferPointer { buf in
                            manga_hub_ingest_text_asset(
                                cDir,
                                cCh,
                                kind.rawValue,
                                cFile,
                                cPayload,
                                buf.baseAddress,
                                buf.count
                            )
                        }
                    }
                }
            }
        }
        guard written > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// `S2 v0.4` — Freehand Lasso Polygon Selection Mask with invert & morphological expand/contract.
public enum MangaSelectionEngine {
    public static func lassoPixelCount(
        xs: [Float],
        ys: [Float],
        width: UInt32,
        height: UInt32,
        invert: Bool = false,
        borderDeltaPx: Int32 = 0
    ) -> Int {
        guard xs.count == ys.count, xs.count >= 3 else { return 0 }
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                Int(
                    manga_selection_lasso_pixel_count(
                        xBuf.baseAddress,
                        yBuf.baseAddress,
                        xs.count,
                        width,
                        height,
                        invert ? 1 : 0,
                        borderDeltaPx
                    )
                )
            }
        }
    }
}

/// `S2 v0.5` — Symmetry, Parallel, 2-Point Perspective & Radial Focus-Line Manga Rulers.
public enum MangaRulerEngine {
    public static func transformPoint(
        mode: RulerModeKind,
        paramX: Float,
        paramY: Float,
        paramAux: Float,
        anchorX: Float,
        anchorY: Float,
        inX: Float,
        inY: Float
    ) -> (x: Float, y: Float) {
        guard mode != .off else { return (inX, inY) }
        var ox: Float = inX
        var oy: Float = inY
        _ = manga_ruler_transform_point(
            mode.rawValue,
            paramX,
            paramY,
            paramAux,
            anchorX,
            anchorY,
            inX,
            inY,
            &ox,
            &oy
        )
        return (ox, oy)
    }
}

/// `S1/S3 v0.5` — 5-Locale Project Glossary (`bible/glossary.xml`) atomic writer (`S1`) & RO autocomplete (`S3`).
public enum MangaGlossary {
    @discardableResult
    public static func upsertTerm(
        projectDir: String,
        key: String,
        en: String,
        zhHans: String,
        zhHant: String,
        yueHant: String,
        es: String,
        locked: Bool = true
    ) -> Bool {
        projectDir.withCString { cDir in
            key.withCString { cKey in
                en.withCString { cEn in
                    zhHans.withCString { cZhS in
                        zhHant.withCString { cZhT in
                            yueHant.withCString { cYue in
                                es.withCString { cEs in
                                    manga_glossary_upsert_term(
                                        cDir,
                                        cKey,
                                        cEn,
                                        cZhS,
                                        cZhT,
                                        cYue,
                                        cEs,
                                        locked ? 1 : 0
                                    ) != 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public static func suggestTerms(projectDir: String, query: String, locale: String) -> [GlossaryTermSummary] {
        var buffer = [CChar](repeating: 0, count: 16_384)
        let written = projectDir.withCString { cDir in
            query.withCString { cQ in
                locale.withCString { cLoc in
                    buffer.withUnsafeMutableBufferPointer { buf in
                        manga_glossary_suggest_terms(cDir, cQ, cLoc, buf.baseAddress, buf.count)
                    }
                }
            }
        }
        guard written > 0 else { return [] }
        let raw = String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return raw.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { return nil }
            return GlossaryTermSummary(
                id: parts[0],
                localizedValue: parts[1],
                en: parts[2],
                zhHans: parts[3],
                status: parts[4]
            )
        }
    }
}

/// `T0.2-S4`, `T0.3-S4`, `T0.4-S4` & `T0.5-S4` — Tri-App Integration & Compatibility Gates over Rust C-ABI.
public enum MangaSuiteS4Gate {
    public static func run(projectDir: String, soakRounds: UInt32 = 100) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_s4_gate(cDir, soakRounds) != 0
        }
    }

    public static func runT03S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t03_s4_gate(cDir) != 0
        }
    }

    public static func runT04S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t04_s4_gate(cDir) != 0
        }
    }

    public static func runT05S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t05_s4_gate(cDir) != 0
        }
    }

    public static func runT06S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t06_s4_gate(cDir) != 0
        }
    }

    public static func runT07S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t07_s4_gate(cDir) != 0
        }
    }

    public static func runT08S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t08_s4_gate(cDir) != 0
        }
    }

    public static func runT09S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t09_s4_gate(cDir) != 0
        }
    }

    public static func runT10S4(projectDir: String) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_t10_s4_gate(cDir) != 0
        }
    }
}

/// `v1.0` — Embedded Local Gemma 4 Dual-Direction AI Reference Bridge (`ai_assist/` isolated).
public enum MangaGemmaAiBridge {
    public static func recommendPack(deviceRamGb: UInt32) -> GemmaModelPackKind {
        let code = manga_ai_recommend_gemma_pack(deviceRamGb)
        return GemmaModelPackKind(rawValue: code) ?? .gemma4E2b
    }

    public static func generateMangaToNovelRef(
        projectDir: String,
        chapterId: String,
        locale: String,
        beatSummary: String,
        pack: GemmaModelPackKind = .gemma4E2b
    ) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let written = projectDir.withCString { cDir in
            chapterId.withCString { cCh in
                locale.withCString { cLoc in
                    beatSummary.withCString { cBeat in
                        buffer.withUnsafeMutableBufferPointer { buf in
                            manga_ai_bridge_generate_manga_to_novel(
                                cDir,
                                cCh,
                                cLoc,
                                cBeat,
                                pack.rawValue,
                                buf.baseAddress,
                                buf.count
                            )
                        }
                    }
                }
            }
        }
        guard written > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    public static func generateNovelToMangaRef(
        projectDir: String,
        chapterId: String,
        proseExcerpt: String,
        pack: GemmaModelPackKind = .gemma4E4b
    ) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let written = projectDir.withCString { cDir in
            chapterId.withCString { cCh in
                proseExcerpt.withCString { cProse in
                    buffer.withUnsafeMutableBufferPointer { buf in
                        manga_ai_bridge_generate_novel_to_manga(
                            cDir,
                            cCh,
                            cProse,
                            pack.rawValue,
                            buf.baseAddress,
                            buf.count
                        )
                    }
                }
            }
        }
        guard written > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// `v0.9` — Pre-1.0 Apple Wave 1 Joint Beta Dual-Track Stress Benchmark.
public enum MangaBetaStressBench {
    public static func runB4FiftyStepCowUndoBenchmarkUs() -> UInt64 {
        manga_beta_b4_50layer_undo_benchmark_us()
    }
}

/// `v0.8` — Apple Trio Touch/Stylus Gestures, Foldable Hinge Geometry & Live 5-Language Catalog.
public enum MangaErgonomicsEngine {
    public static func resolveGesture(
        touchCount: UInt8,
        durationMs: Float,
        maxTravelPx: Float,
        contactRadiusPx: Float,
        stylusActive: Bool,
        pencilSqueeze: Bool
    ) -> GestureActionKind {
        let code = manga_gesture_resolve(
            touchCount,
            durationMs,
            maxTravelPx,
            contactRadiusPx,
            stylusActive ? 1 : 0,
            pencilSqueeze ? 1 : 0
        )
        return GestureActionKind(rawValue: code) ?? .none
    }

    public static func computeFoldablePanes(
        viewportWidthDp: Float,
        posture: FoldPostureKind,
        reportedCreaseDp: Float = 16
    ) -> (isSplit: Bool, leftWidth: Float, rightWidth: Float, hingeWidth: Float) {
        var left: Float = viewportWidthDp
        var right: Float = 0
        var hinge: Float = 0
        let split = manga_foldable_compute_pane_widths(
            viewportWidthDp,
            posture.rawValue,
            reportedCreaseDp,
            &left,
            &right,
            &hinge
        ) != 0
        return (split, left, right, hinge)
    }

    public static func translate(key: String, locale: UiLocaleKind) -> String {
        var buffer = [CChar](repeating: 0, count: 512)
        let written = key.withCString { cKey in
            buffer.withUnsafeMutableBufferPointer { buf in
                manga_i18n_translate_key(locale.rawValue, cKey, buf.baseAddress, buf.count)
            }
        }
        guard written > 0 else { return key }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// `S2/S3 v0.7` — Open `.mnga` atomic persistence, Adobe PSD (`8BPS`) export & Novel Illustration Slots.
public enum MangaPersistenceTools {
    public static func validateNovelIllustrationSlot(modeCode: UInt32, relSrc: String) -> Bool {
        relSrc.withCString { cRel in
            manga_novel_validate_illustration_slot(modeCode, cRel) != 0
        }
    }
}

/// `S1/S2/S3 v0.6` — Procedural Halftone Screentones, Webtoon Slicer & EPUB3 XHTML Renderer.
public enum MangaPublishingTools {
    public static func sampleScreentoneMask(
        lpi: Float = 60,
        dpi: Float = 600,
        angleDeg: Float = 45,
        density: Float = 0.30,
        patternCode: UInt32 = 0,
        x: UInt32,
        y: UInt32
    ) -> Bool {
        manga_screentone_sample_mask(lpi, dpi, angleDeg, density, patternCode, x, y) != 0
    }

    public static func webtoonSliceCount(canvasHeight: UInt32, sliceHeight: UInt32 = 1280) -> Int {
        Int(manga_webtoon_slice_count(canvasHeight, sliceHeight))
    }

    public static func renderEpubXhtml(title: String, locale: String, markdown: String) -> String {
        var buffer = [CChar](repeating: 0, count: 32_768)
        let written = title.withCString { cTitle in
            locale.withCString { cLoc in
                markdown.withCString { cMd in
                    buffer.withUnsafeMutableBufferPointer { buf in
                        manga_novel_render_epub_xhtml(cTitle, cLoc, cMd, buf.baseAddress, buf.count)
                    }
                }
            }
        }
        guard written > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

/// Type-safe RAII wrapper over the Rust `MangaCanvasHandle` C-ABI (single-canvas low-latency path).
public final class MangaCanvasEngine {
    private var handle: OpaquePointer

    public init?(preset: CanvasPresetKind) {
        guard let ptr = manga_canvas_create_preset(preset.rawValue) else {
            return nil
        }
        self.handle = ptr
    }

    deinit {
        manga_canvas_destroy(handle)
    }

    public var width: UInt32 { manga_canvas_width(handle) }
    public var height: UInt32 { manga_canvas_height(handle) }
    public var allocatedTiles: Int { Int(manga_canvas_allocated_tiles(handle)) }

    public func setViewport(panX: Float, panY: Float, zoom: Float, rotationRad: Float) {
        manga_canvas_set_viewport(handle, panX, panY, zoom, rotationRad)
    }

    public func beginStroke(
        radius: Float,
        rgba: (UInt8, UInt8, UInt8, UInt8),
        isEraser: Bool = false,
        stabilizerRadius: Float = 4.0
    ) {
        manga_canvas_begin_stroke(
            handle,
            radius,
            rgba.0,
            rgba.1,
            rgba.2,
            rgba.3,
            isEraser ? 1 : 0,
            stabilizerRadius
        )
    }

    @discardableResult
    public func pushPoints(_ samples: [NativeStrokeSample]) -> Int {
        guard !samples.isEmpty else { return 0 }
        let cPoints = samples.map { s in
            CMangaStrokePoint(
                x: s.x,
                y: s.y,
                pressure: s.pressure,
                altitude: s.altitude,
                azimuth: s.azimuth,
                roll_angle: s.rollAngle,
                timestamp_ms: s.timestampMs,
                is_predicted: s.isPredicted ? 1 : 0
            )
        }
        return cPoints.withUnsafeBufferPointer { buf in
            Int(manga_canvas_push_points(handle, buf.baseAddress, buf.count))
        }
    }

    @discardableResult
    public func endStroke() -> Int {
        Int(manga_canvas_end_stroke(handle))
    }

    @discardableResult
    public func undo() -> Bool {
        manga_canvas_undo(handle) != 0
    }

    @discardableResult
    public func redo() -> Bool {
        manga_canvas_redo(handle) != 0
    }
}

/// Type-safe RAII wrapper over `MangaProjectHandle` (multi-layer, Close-Gap fill,
/// Vector Intersection Eraser, Panel slicing, and transactional `ActionBus` macros).
public final class MangaProjectEngine {
    private var handle: OpaquePointer

    public init?(preset: CanvasPresetKind) {
        guard let ptr = manga_project_create_preset(preset.rawValue) else {
            return nil
        }
        self.handle = ptr
    }

    deinit {
        manga_project_destroy(handle)
    }

    public var layerCount: Int { Int(manga_project_layer_count(handle)) }
    public var vectorStrokeCount: Int { Int(manga_project_vector_stroke_count(handle)) }
    public var panelCount: Int { Int(manga_project_panel_count(handle)) }

    @discardableResult
    public func addRasterLayer(
        name: String,
        blendMode: LayerBlendMode = .normal,
        clippingMask: Bool = false,
        isReference: Bool = false
    ) -> UInt64 {
        name.withCString { cName in
            manga_project_add_raster_layer(
                handle,
                cName,
                blendMode.rawValue,
                clippingMask ? 1 : 0,
                isReference ? 1 : 0
            )
        }
    }

    @discardableResult
    public func batchTintLayers(
        prefix: String,
        rgba: (UInt8, UInt8, UInt8, UInt8),
        opacity: Float,
        lock: Bool
    ) -> Int {
        prefix.withCString { cPrefix in
            Int(
                manga_project_batch_tint_layers(
                    handle,
                    cPrefix,
                    rgba.0,
                    rgba.1,
                    rgba.2,
                    rgba.3,
                    opacity,
                    lock ? 1 : 0
                )
            )
        }
    }

    @discardableResult
    public func closeGapFill(
        layerId: UInt64,
        seedX: UInt32,
        seedY: UInt32,
        rgba: (UInt8, UInt8, UInt8, UInt8),
        closeGapPx: UInt8 = 3,
        expandPx: UInt8 = 1
    ) -> Int {
        Int(
            manga_project_close_gap_fill(
                handle,
                layerId,
                seedX,
                seedY,
                rgba.0,
                rgba.1,
                rgba.2,
                rgba.3,
                closeGapPx,
                expandPx
            )
        )
    }

    @discardableResult
    public func addVectorStroke(
        xs: [Float],
        ys: [Float],
        widths: [Float],
        rgba: (UInt8, UInt8, UInt8, UInt8)
    ) -> UInt64 {
        let count = min(xs.count, min(ys.count, widths.count))
        guard count >= 2 else { return 0 }
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                widths.withUnsafeBufferPointer { wBuf in
                    manga_project_add_vector_stroke(
                        handle,
                        xBuf.baseAddress,
                        yBuf.baseAddress,
                        wBuf.baseAddress,
                        count,
                        rgba.0,
                        rgba.1,
                        rgba.2,
                        rgba.3
                    )
                }
            }
        }
    }

    @discardableResult
    public func eraseVectorToIntersection(hitX: Float, hitY: Float, hitRadius: Float) -> Bool {
        manga_project_vector_erase_intersection(handle, hitX, hitY, hitRadius) != 0
    }

    @discardableResult
    public func slicePanel(
        panelId: UInt64,
        from a: (Float, Float),
        to b: (Float, Float),
        gutterPx: Float
    ) -> Int {
        Int(manga_project_slice_panel(handle, panelId, a.0, a.1, b.0, b.1, gutterPx))
    }

    @discardableResult
    public func undoAction() -> Bool {
        manga_project_undo_action(handle) != 0
    }

    @discardableResult
    public func redoAction() -> Bool {
        manga_project_redo_action(handle) != 0
    }

    /// `S2 v0.3.1` — Updates `R` (reference), `✂` (clipping), `🔒` (alpha lock), `B` (blue sketch),
    /// 13 cel blend modes, visibility, and opacity directly in Rust `LayerStack`.
    @discardableResult
    public func setLayerFlags(
        layerId: UInt64,
        visible: Bool,
        alphaLock: Bool,
        clippingMask: Bool,
        isReference: Bool,
        blendMode: LayerBlendMode,
        opacity: Float,
        blueSketchTint: Bool
    ) -> Bool {
        return manga_project_set_layer_flags(
            handle,
            layerId,
            visible ? 1 : 0,
            alphaLock ? 1 : 0,
            clippingMask ? 1 : 0,
            isReference ? 1 : 0,
            blendMode.rawValue,
            opacity,
            blueSketchTint ? 1 : 0
        ) != 0
    }

    /// `S2 v0.7` — Atomically saves a `.mnga` manuscript snapshot (FNV-1a checksummed) under `SuiteApp::Manga` ownership.
    @discardableResult
    public func saveMngaSnapshot(
        projectDir: String,
        relPath: String,
        dpi: UInt16 = 600,
        timelapseEvents: UInt32 = 0
    ) -> Int {
        projectDir.withCString { cDir in
            relPath.withCString { cRel in
                Int(manga_mnga_save_snapshot(handle, cDir, cRel, dpi, timelapseEvents))
            }
        }
    }

    /// `S2 v0.7` — Exports a standards-compliant Adobe PSD (`8BPS` v1 RGB8) interchange payload and returns byte count.
    public func psdExportByteLength() -> Int {
        Int(manga_psd_export_byte_len(handle))
    }

    /// `S2 v1.0-rc2` — Atomically saves full `MNGA0002` archive (all layers + RLE-compressed sparse pixel tiles + `.mnga.bak`).
    @discardableResult
    public func saveMngaV2(
        projectDir: String,
        relPath: String,
        dpi: UInt16 = 600,
        timelapseEvents: UInt32 = 0
    ) -> Int {
        projectDir.withCString { cDir in
            relPath.withCString { cRel in
                Int(manga_project_save_mnga_v2(handle, cDir, cRel, dpi, timelapseEvents))
            }
        }
    }

    /// `S2 v1.0-rc2` — Restores full `MNGA0002` archive (auto-recovering from `.mnga.bak` if primary is corrupted).
    @discardableResult
    public func loadMngaV2(projectDir: String, relPath: String) -> Bool {
        projectDir.withCString { cDir in
            relPath.withCString { cRel in
                manga_project_load_mnga_v2(handle, cDir, cRel) != 0
            }
        }
    }
}

/// `S1/S2/S3 v0.3.1` — Story Bible (`bible/characters.xml`) atomic writer (`S1`) and
/// `< 300ms` cross-app hot-reload revision fingerprint (`S2`/`S3` RO).
public enum MangaStoryBible {
    @discardableResult
    public static func upsertCharacter(
        projectDir: String,
        id: String,
        nameZh: String,
        nameEn: String,
        role: String = "supporting",
        paletteHex: String = "#4F7CFF"
    ) -> Bool {
        projectDir.withCString { cDir in
            id.withCString { cId in
                nameZh.withCString { cZh in
                    nameEn.withCString { cEn in
                        role.withCString { cRole in
                            paletteHex.withCString { cHex in
                                manga_bible_upsert_character(cDir, cId, cZh, cEn, cRole, cHex) != 0
                            }
                        }
                    }
                }
            }
        }
    }

    public static func characterCount(projectDir: String) -> Int {
        projectDir.withCString { cDir in
            Int(manga_bible_character_count(cDir))
        }
    }

    public static func revisionHash(projectDir: String) -> UInt64 {
        projectDir.withCString { cDir in
            manga_bible_revision_hash(cDir)
        }
    }

    public static func readCharacters(projectDir: String) -> [StoryBibleCharacterSummary] {
        var buffer = [CChar](repeating: 0, count: 16_384)
        let written = projectDir.withCString { cDir in
            buffer.withUnsafeMutableBufferPointer { buf in
                manga_bible_read_summary(cDir, buf.baseAddress, buf.count)
            }
        }
        guard written > 0 else { return [] }
        let raw = String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return raw.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { return nil }
            return StoryBibleCharacterSummary(
                id: parts[0],
                nameZh: parts[1],
                nameEn: parts[2],
                role: parts[3],
                paletteHex: parts[4]
            )
        }
    }

    @discardableResult
    public static func upsertTocEntry(
        projectDir: String,
        chapterId: String,
        number: UInt32,
        titleZh: String,
        titleEn: String,
        status: String = "draft"
    ) -> Bool {
        projectDir.withCString { cDir in
            chapterId.withCString { cId in
                titleZh.withCString { cZh in
                    titleEn.withCString { cEn in
                        status.withCString { cStatus in
                            manga_toc_upsert_entry(cDir, cId, number, cZh, cEn, cStatus) != 0
                        }
                    }
                }
            }
        }
    }

    public static func readTocEntries(projectDir: String) -> [ProjectTocEntrySummary] {
        var buffer = [CChar](repeating: 0, count: 16_384)
        let written = projectDir.withCString { cDir in
            buffer.withUnsafeMutableBufferPointer { buf in
                manga_toc_read_summary(cDir, buf.baseAddress, buf.count)
            }
        }
        guard written > 0 else { return [] }
        let raw = String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return raw.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { return nil }
            return ProjectTocEntrySummary(
                id: parts[0],
                number: UInt32(parts[1]) ?? 1,
                titleZh: parts[2],
                titleEn: parts[3],
                status: parts[4]
            )
        }
    }
}
#endif
