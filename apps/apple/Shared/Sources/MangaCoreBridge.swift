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
}

/// `T0.2-S4` — Tri-App Integration & 100-Round Concurrency Soak Gate over Rust C-ABI.
public enum MangaSuiteS4Gate {
    public static func run(projectDir: String, soakRounds: UInt32 = 100) -> Bool {
        projectDir.withCString { cDir in
            manga_suite_run_s4_gate(cDir, soakRounds) != 0
        }
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
        manga_project_set_layer_flags(
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
}
#endif
