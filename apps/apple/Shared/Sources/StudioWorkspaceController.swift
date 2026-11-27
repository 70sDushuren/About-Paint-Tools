import Foundation

#if canImport(SwiftUI)
import SwiftUI
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - ibisPaint-Aligned S2 Tooling, Ruler, Shape, Lasso & Filter Enums

public enum S2DrawingToolKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case brush
    case eraser
    case smudge
    case blur
    case bucket
    case lasso
    case rectSelect
    case magicWand
    case eyedropper
    case transform
    case ruler
    case panelKnife
    case textBubble
    case handPan

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .brush: return "Brush"
        case .eraser: return "Eraser"
        case .smudge: return "Smudge"
        case .blur: return "Blur"
        case .bucket: return "Bucket"
        case .lasso: return "Lasso"
        case .rectSelect: return "Marquee"
        case .magicWand: return "Magic Wand"
        case .eyedropper: return "Eyedropper"
        case .transform: return "Transform"
        case .ruler: return "Ruler"
        case .panelKnife: return "Frame Divider"
        case .textBubble: return "Text / Bubble"
        case .handPan: return "Pan / Move Canvas"
        }
    }

    public var systemSymbol: String {
        switch self {
        case .brush: return "paintbrush.pointed.fill"
        case .eraser: return "eraser.fill"
        case .smudge: return "hand.draw.fill"
        case .blur: return "drop.halffull"
        case .bucket: return "drop.fill"
        case .lasso: return "lasso"
        case .rectSelect: return "rectangle.dashed"
        case .magicWand: return "wand.and.stars"
        case .eyedropper: return "eyedropper"
        case .transform: return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .ruler: return "ruler.fill"
        case .panelKnife: return "rectangle.split.2x2"
        case .textBubble: return "text.bubble.fill"
        case .handPan: return "hand.raised.fill"
        }
    }

    public var usesBrushDynamics: Bool {
        switch self {
        case .brush, .eraser, .smudge, .blur: return true
        default: return false
        }
    }

    public var isSelectionTool: Bool {
        switch self {
        case .lasso, .rectSelect, .magicWand: return true
        default: return false
        }
    }
}

/// ibisPaint X Lasso sub-mode:
/// - `.selection`: Standard freehand lasso selection (with New / Add + / Subtract - / Drag-inside-to-move)
/// - `.lassoFill`: ibisPaint signature speed-painting "Lasso Fill" (套索填色) — immediately fills enclosed loop on release
/// - `.lassoEraser`: ibisPaint "Lasso Eraser" (套索橡皮) — immediately erases pixels inside enclosed loop on release
public enum S2LassoWorkMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case selection
    case lassoFill
    case lassoEraser

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .selection: return "自由选区 Lasso"
        case .lassoFill: return "套索填色 Fill"
        case .lassoEraser: return "套索橡皮 Erase"
        }
    }

    public var systemSymbol: String {
        switch self {
        case .selection: return "lasso"
        case .lassoFill: return "lasso.badge.sparkles"
        case .lassoEraser: return "eraser.line.dashed.fill"
        }
    }
}

/// ibisPaint X Selection Boolean Combine Mode:
/// - `.replace`: Creates a fresh selection
/// - `.add`: Adds (`+`) the newly lassoed/marqueed region to the existing selection
/// - `.subtract`: Subtracts (`-`) the newly lassoed/marqueed region from the existing selection
public enum S2SelectionCombineMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case replace
    case add
    case subtract

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .replace: return "新选区"
        case .add: return "+ 加选"
        case .subtract: return "- 减选"
        }
    }

    public var systemSymbol: String {
        switch self {
        case .replace: return "plus.square.dashed"
        case .add: return "plus.circle.fill"
        case .subtract: return "minus.circle.fill"
        }
    }
}

public enum S2ShapeAssistKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case freehand
    case line
    case rectangle
    case ellipse

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .freehand: return "Freehand"
        case .line: return "Line"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        }
    }
}

public enum S2CanvasBackdropKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case whitePaper
    case transparentLight
    case transparentDark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whitePaper: return "White Paper"
        case .transparentLight: return "Checker (Light)"
        case .transparentDark: return "Checker (Dark)"
        }
    }

    public var rustBackdropCode: UInt32 {
        switch self {
        case .whitePaper: return 0
        case .transparentLight: return 1
        case .transparentDark: return 2
        }
    }
}

public enum S2FilterActionKind: String, CaseIterable, Sendable, Identifiable {
    case gaussianBlur
    case hsbAdjust
    case brightnessContrast
    case extractLineDrawing
    case outerStroke
    case dropShadow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gaussianBlur: return "Gaussian Blur"
        case .hsbAdjust: return "Hue / Saturation / Brightness"
        case .brightnessContrast: return "Brightness & Contrast"
        case .extractLineDrawing: return "Extract Line Drawing"
        case .outerStroke: return "Stroke (Outer)"
        case .dropShadow: return "Drop Shadow"
        }
    }
}

public struct PersistedRGBA: Codable, Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public var swiftUIColor: Color {
        Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }
}

public struct PersistedStrokePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double

    public init(x: Double, y: Double, width: Double) {
        self.x = x
        self.y = y
        self.width = width
    }
}

public struct PersistedCanvasStroke: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var layerId: UInt64
    public var points: [PersistedStrokePoint]
    public var color: PersistedRGBA
    public var opacity: Double
    public var isEraser: Bool
    public var tool: S2DrawingToolKind

    public init(
        id: UUID = UUID(),
        layerId: UInt64,
        points: [PersistedStrokePoint],
        color: PersistedRGBA,
        opacity: Double = 1.0,
        isEraser: Bool = false,
        tool: S2DrawingToolKind = .brush
    ) {
        self.id = id
        self.layerId = layerId
        self.points = points
        self.color = color
        self.opacity = opacity
        self.isEraser = isEraser
        self.tool = tool
    }
}

public struct PersistedLayerRecord: Codable, Equatable, Sendable {
    public var id: UInt64
    public var name: String
    public var visible: Bool
    public var isReference: Bool
    public var clippingMask: Bool
    public var alphaLock: Bool
    public var blueSketchTint: Bool
    public var blendModeRaw: UInt32
    public var opacity: Double

    public init(from item: CelLayerRowItem) {
        self.id = item.id
        self.name = item.name
        self.visible = item.visible
        self.isReference = item.isReference
        self.clippingMask = item.clippingMask
        self.alphaLock = item.alphaLock
        self.blueSketchTint = item.blueSketchTint
        self.blendModeRaw = item.blendMode.rawValue
        self.opacity = item.opacity
    }

    public func toCelLayerRowItem() -> CelLayerRowItem {
        CelLayerRowItem(
            id: id,
            name: name,
            visible: visible,
            isReference: isReference,
            clippingMask: clippingMask,
            alphaLock: alphaLock,
            blueSketchTint: blueSketchTint,
            blendMode: LayerBlendMode(rawValue: blendModeRaw) ?? .normal,
            opacity: opacity
        )
    }
}

// MARK: - 3-Layer Persistence Schemas

public struct GlobalAppSessionState: Codable, Equatable, Sendable {
    public var lastProjectDir: String
    public var recentProjectDirs: [String]
    public var activeSuiteAppRaw: UInt32
    public var workspaceModeRaw: String
    public var activeLocaleRaw: UInt32
    public var hintModeActive: Bool

    public init(
        lastProjectDir: String,
        recentProjectDirs: [String],
        activeSuiteAppRaw: UInt32,
        workspaceModeRaw: String,
        activeLocaleRaw: UInt32,
        hintModeActive: Bool
    ) {
        self.lastProjectDir = lastProjectDir
        self.recentProjectDirs = recentProjectDirs
        self.activeSuiteAppRaw = activeSuiteAppRaw
        self.workspaceModeRaw = workspaceModeRaw
        self.activeLocaleRaw = activeLocaleRaw
        self.hintModeActive = hintModeActive
    }
}

public struct ProjectWorkspaceSessionState: Codable, Equatable, Sendable {
    // S1 Hub
    public var hubSectionRaw: String
    // S2 Manga
    public var s2Tool: S2DrawingToolKind
    public var s2PresetIndex: UInt32
    public var s2CanvasPresetRaw: UInt32
    public var s2BrushSize: Double
    public var s2BrushOpacity: Double
    public var s2ForceFade: Bool
    public var s2StabilizerPx: Double
    public var s2BucketCloseGapPx: Int
    public var s2BucketExpandPx: Int
    public var s2BucketTolerance: Int
    public var s2ViewportZoom: Double
    public var s2PanX: Double
    public var s2PanY: Double
    public var s2RotationDeg: Double
    public var s2MirrorHorizontal: Bool
    public var s2Backdrop: S2CanvasBackdropKind
    public var s2ActiveColor: PersistedRGBA
    public var s2RecentColors: [PersistedRGBA]
    public var s2RulerModeRaw: UInt32
    public var s2ShapeAssist: S2ShapeAssistKind
    public var s2ShowBrushDrawer: Bool
    public var s2ShowLayerDrawer: Bool
    public var s2ShowReferenceWindow: Bool
    public var s2SelectedLayerId: UInt64
    public var s2Layers: [PersistedLayerRecord]
    public var s2Strokes: [PersistedCanvasStroke]
    public var s2SpeechBubbles: [PersistedSpeechBubble]?
    public var s2ApplePencilOnlyDraw: Bool?
    public var s2CanvasPixelWidth: Int?
    public var s2CanvasPixelHeight: Int?
    // S3 Novel
    public var s3SelectedChapterId: String
    public var s3ActiveProseLocale: String
    public var s3PaperThemeRaw: String
    public var s3ZenMode: Bool
    public var s3ShowOutline: Bool
    public var s3ShowAiRefDrawer: Bool
    public var s3HumanLocked: Bool
    public var savedAtEpochSec: Double
}

public struct CanvasSizePresetOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let width: Int
    public let height: Int
    public let preset: CanvasPresetKind

    public static let allPresets: [CanvasSizePresetOption] = [
        CanvasSizePresetOption(id: "b5", title: "B5 漫画标准", subtitle: "800 × 1132 · 轻快连载", width: 800, height: 1132, preset: .b4PrintManga600Dpi),
        CanvasSizePresetOption(id: "a4", title: "A4 日漫原稿", subtitle: "1000 × 1414 · 同人本", width: 1000, height: 1414, preset: .a4PrintManga600Dpi),
        CanvasSizePresetOption(id: "b4", title: "B4 商业漫画 HD", subtitle: "1200 × 1698 · 印刷比例", width: 1200, height: 1698, preset: .b4PrintManga600Dpi),
        CanvasSizePresetOption(id: "4k", title: "宽屏插画 16:9", subtitle: "1920 × 1080 · 彩插/封面", width: 1920, height: 1080, preset: .illustration4K),
        CanvasSizePresetOption(id: "sq", title: "角色人设 1:1", subtitle: "1200 × 1200 · 头像/立绘", width: 1200, height: 1200, preset: .illustration4K),
        CanvasSizePresetOption(id: "webtoon", title: "条漫长卷 Webtoon", subtitle: "800 × 2400 · 竖屏滚动", width: 800, height: 2400, preset: .webtoonStrip800),
    ]
}

public struct CanvasGalleryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let width: Int
    public let height: Int
    public let layerCount: Int
    public let modifiedAt: Date
    public let thumbnailPath: String?
    public let isActive: Bool
}

public struct PersistedSpeechBubble: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var normX: Double
    public var normY: Double
    public var text: String
    public var isVertical: Bool

    public init(id: UUID = UUID(), normX: Double, normY: Double, text: String, isVertical: Bool = true) {
        self.id = id
        self.normX = normX
        self.normY = normY
        self.text = text
        self.isVertical = isVertical
    }
}

/// Captures Swift-side layer metadata & active layer selection in 1:1 lockstep with Rust `LayerStack` undo/redo snapshots.
private struct SwiftLayerUndoState: Equatable, Sendable {
    let layers: [CelLayerRowItem]
    let selectedLayerId: UInt64
}

/// Unified `@MainActor` studio controller acting as Single Source of Truth for:
/// 1. Context-aware macOS/iPadOS Menu Bar (`StudioMenuCommands`) ↔ UI controls 1:1 synchronization.
/// 2. State survival when switching between `S1 Hub`, `S2 Manga`, and `S3 Novel`.
/// 3. 3-Layer crash-safe automatic persistence (`app_state.json` + `.about-paint-session.json` +
///    CPFF `.mnga` v2 / `novel/prose/<lang>.md`) restoring exact workspace state on relaunch.
@MainActor
public final class StudioWorkspaceController: ObservableObject {
    // MARK: - Shell & Global State
    @Published public var platform: TargetPlatformKind
    @Published public var posture: FoldPostureKind = .flat
    @Published public var activeSuiteApp: SuiteAppKind = .manga { didSet { scheduleAutoSave() } }
    @Published public var workspaceMode: StudioWorkspaceMode = .mangaStudio { didSet { scheduleAutoSave() } }
    @Published public var activeLocale: UiLocaleKind = .zhHans { didSet { scheduleAutoSave() } }
    @Published public var hintModeActive: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var hingeAvoidanceWidthPt: CGFloat = 0

    // MARK: - Project & Persistence State
    @Published public var activeProjectDir: String
    @Published public var recentProjectDirs: [String] = []
    @Published public var hasUnsavedChanges: Bool = false
    @Published public var saveStatusBadge: String = "Saved"
    @Published public var lastStatusBanner: String = "Ready"

    // MARK: - S1 Hub State
    @Published public var hubSection: HubSectionKind = .overview { didSet { scheduleAutoSave() } }

    // MARK: - S2 Manga Canvas State (preserved across tool switches & restarts!)
    @Published public var s2Tool: S2DrawingToolKind = .brush { didSet { scheduleAutoSave() } }
    @Published public var s2PresetIndex: UInt32 = 0 { didSet { scheduleAutoSave() } }
    @Published public var s2CanvasPreset: CanvasPresetKind = .b4PrintManga600Dpi
    @Published public var s2BrushSize: Double = 8.0 {
        didSet {
            if !isRestoring && abs(s2BrushSize - oldValue) >= 0.1 {
                triggerBrushSizePreviewHUD()
            }
        }
    }
    @Published public var s2ShowBrushSizePreviewHUD: Bool = false
    @Published public var s2BrushOpacity: Double = 1.0
    @Published public var s2ForceFade: Bool = true { didSet { scheduleAutoSave() } }
    @Published public var s2ApplePencilOnlyDraw: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2StabilizerPx: Double = 6.0
    @Published public var s2BucketCloseGapPx: Int = 3 { didSet { scheduleAutoSave() } }
    @Published public var s2BucketExpandPx: Int = 1 { didSet { scheduleAutoSave() } }
    @Published public var s2BucketTolerance: Int = 24 { didSet { scheduleAutoSave() } }
    @Published public var s2PanelGutterPx: Double = 14.0
    @Published public var s2ScreentoneLpi: Double = 60.0
    @Published public var s2ScreentoneDensity: Double = 0.28
    @Published public var s2EyedropperAutoSwitchToBrush: Bool = true
    @Published public var s2ViewportZoom: Double = 1.0
    @Published public var s2PanOffset: CGSize = .zero
    @Published public var s2RotationDeg: Double = 0.0
    @Published public var s2MirrorHorizontal: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2Backdrop: S2CanvasBackdropKind = .whitePaper { didSet { refreshCompositeImage(); scheduleAutoSave() } }
    @Published public var s2ActiveColor: PersistedRGBA = PersistedRGBA(r: 20, g: 22, b: 28, a: 255) { didSet { scheduleAutoSave() } }
    @Published public var s2RecentColors: [PersistedRGBA] = [
        PersistedRGBA(r: 20, g: 22, b: 28),
        PersistedRGBA(r: 255, g: 107, b: 74),
        PersistedRGBA(r: 79, g: 124, b: 255),
        PersistedRGBA(r: 47, g: 168, b: 139),
        PersistedRGBA(r: 255, g: 209, b: 102),
        PersistedRGBA(r: 139, g: 92, b: 246),
    ]
    @Published public var s2RulerMode: RulerModeKind = .off { didSet { scheduleAutoSave() } }
    @Published public var s2ShapeAssist: S2ShapeAssistKind = .freehand { didSet { scheduleAutoSave() } }
    @Published public var s2LassoWorkMode: S2LassoWorkMode = .selection
    @Published public var s2SelectionCombineMode: S2SelectionCombineMode = .replace
    @Published public var s2LassoDragInsideMovesPixels: Bool = true
    @Published public var s2LiveTransformPreviewOffsetNorm: CGSize = .zero
    @Published public var s2ShowBrushDrawer: Bool = true { didSet { scheduleAutoSave() } }
    @Published public var s2ShowLayerDrawer: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2ShowReferenceWindow: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2CelLayers: [CelLayerRowItem] = []
    @Published public var s2SelectedLayerId: UInt64 = 2 { didSet { scheduleAutoSave() } }
    @Published public var s2Strokes: [PersistedCanvasStroke] = []
    @Published public var s2UndoneStrokes: [PersistedCanvasStroke] = []
    @Published public var s2SpeechBubbles: [PersistedSpeechBubble] = [] { didSet { scheduleAutoSave() } }
    @Published public var s2HasActiveSelection: Bool = false
    @Published public var s2SelectionPixelCount: Int = 0
    @Published public var s2SelectionRectNorm: CGRect? = nil
    @Published public var s2SelectionLassoNorm: [CGPoint] = []
    @Published public var s2LiveLassoNorm: [CGPoint] = []
    @Published public var s2LiveMarqueeStartNorm: CGPoint? = nil
    @Published public var s2LiveMarqueeCurrentNorm: CGPoint? = nil
    @Published public var s2AllocatedTiles: Int = 0
    @Published public var s2CanvasPixelWidth: Int = 800
    @Published public var s2CanvasPixelHeight: Int = 1132
    @Published public var s2CanUndoRaster: Bool = false
    @Published public var s2CanRedoRaster: Bool = false
    @Published public var s2EyedropperPreview: PersistedRGBA? = nil
    @Published public var s2EyedropperLoupeNorm: CGPoint? = nil
    @Published public var s2PanelCount: Int = 1
    @Published public var s2TransformSelectionOnly: Bool = true
    @Published public var s2TransformKeepOriginal: Bool = false
    @Published public var s2ShowCanvasGallery: Bool = false
    @Published public var s2GalleryItems: [CanvasGalleryItem] = []
    #if canImport(CoreGraphics)
    @Published public var s2CompositeImage: CGImage? = nil
    @Published public var s2ReferenceImage: CGImage? = nil
    #endif
    @Published public var s2PendingFilter: S2FilterActionKind? = nil
    @Published public var s2CanvasActionRevision: Int = 0

    // MARK: - S3 Novel Studio State (loaded from real CPFF prose files & auto-saved!)
    @Published public var s3SelectedChapterId: String = "ch001" { didSet { loadNovelProseFromDisk(); scheduleAutoSave() } }
    @Published public var s3ActiveProseLocale: String = "zh-Hans" { didSet { loadNovelProseFromDisk(); scheduleAutoSave() } }
    @Published public var s3PaperTheme: PaperThemeKind = .warmPaper { didSet { scheduleAutoSave() } }
    @Published public var s3ZenMode: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s3ShowOutline: Bool = true { didSet { scheduleAutoSave() } }
    @Published public var s3ShowAiRefDrawer: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s3HumanLocked: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s3ProseText: String = ""

    // MARK: - Command Event Signals (for Canvas / Export / Dialog triggers)
    @Published public var pendingCanvasCommand: CanvasMenuCommand? = nil

    public enum CanvasMenuCommand: Equatable, Sendable {
        case undo
        case redo
        case clearCurrentLayer
        case clearAllCanvas
        case selectAll
        case deselect
        case invertSelection
        case addLayer
        case duplicateLayer
        case deleteLayer
        case mergeLayerDown
        case flipLayerHorizontal
        case flipLayerVertical
        case resetViewport
        case applyScreentone
        case applyFilter(S2FilterActionKind)
        case exportPng(URL?)
        case exportPsd(URL?)
    }

    /// True while a touch stroke or multi-touch gesture is actively in progress on the canvas.
    /// Prevents background auto-save tasks from performing synchronous disk I/O mid-stroke.
    public var isCanvasInteractionActive: Bool = false

    private let appStateFileUrl: URL
    private var autoSaveTask: Task<Void, Never>?
    private var brushSizePreviewDismissTask: Task<Void, Never>?
    private var trailingCompositeTask: Task<Void, Never>?
    private var lastInteractiveCompositeTime: CFAbsoluteTime = 0
    private var isRestoring: Bool = false
    private var swiftUndoLayerStack: [SwiftLayerUndoState] = []
    private var swiftRedoLayerStack: [SwiftLayerUndoState] = []

    #if canImport(MangaCoreFFI)
    public var rustCanvas: MangaCanvasEngine?
    public var rustProject: MangaProjectEngine?
    #endif

    public init(
        platform: TargetPlatformKind? = nil,
        appStateFileUrl: URL? = nil,
        initialProjectDir: String? = nil
    ) {
        #if os(macOS)
        self.platform = platform ?? .macOsTouch
        #else
        self.platform = platform ?? .ipadOs
        #endif

        if let customUrl = appStateFileUrl {
            self.appStateFileUrl = customUrl
        } else {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.appStateFileUrl = supportDir
                .appendingPathComponent("AboutPaintTools", isDirectory: true)
                .appendingPathComponent("app_state.json")
        }

        let fallbackDir = initialProjectDir ?? SuiteSharedWorkspace.bootstrapDefaultWorkspaceIfNeeded()
        self.activeProjectDir = fallbackDir

        restoreGlobalAndProjectState(overrideProjectDir: initialProjectDir)
    }

    // MARK: - Context-Aware Menu Bar Capability Flags (1:1 with Active Tool & Mode)

    public var isMangaContext: Bool {
        activeSuiteApp == .manga || workspaceMode == .dualNovelManga
    }

    public var isNovelContext: Bool {
        activeSuiteApp == .novel || workspaceMode == .dualNovelManga
    }

    public var isHubContext: Bool {
        activeSuiteApp == .hub && workspaceMode != .dualNovelManga
    }

    public var canUndoInCurrentContext: Bool {
        isMangaContext && (s2CanUndoRaster || !s2Strokes.isEmpty)
    }

    public var canRedoInCurrentContext: Bool {
        isMangaContext && (s2CanRedoRaster || !s2UndoneStrokes.isEmpty)
    }

    public var canAdjustBrushDynamics: Bool {
        isMangaContext && s2Tool.usesBrushDynamics
    }

    public var canAdjustBucketOptions: Bool {
        isMangaContext && s2Tool == .bucket
    }

    public var selectedCelLayerIndex: Int? {
        s2CelLayers.firstIndex(where: { $0.id == s2SelectedLayerId })
    }

    public var selectedCelLayer: CelLayerRowItem? {
        guard let idx = selectedCelLayerIndex else { return nil }
        return s2CelLayers[idx]
    }

    public var canDeleteSelectedLayer: Bool {
        isMangaContext && !s2CelLayers.isEmpty && selectedCelLayerIndex != nil
    }

    public var canMergeSelectedLayerDown: Bool {
        guard isMangaContext, let idx = selectedCelLayerIndex else { return false }
        return idx > 0
    }

    public var canRunFilterOnSelectedLayer: Bool {
        guard isMangaContext, let layer = selectedCelLayer else { return false }
        return layer.visible && !layer.alphaLock
    }

    public var canExportArtwork: Bool {
        isMangaContext
    }

    public var canExportEpub: Bool {
        isNovelContext || isHubContext
    }

    // MARK: - Shared Menu & UI Actions

    public func triggerBrushSizePreviewHUD() {
        if !s2ShowBrushSizePreviewHUD {
            s2ShowBrushSizePreviewHUD = true
        }
        brushSizePreviewDismissTask?.cancel()
        brushSizePreviewDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self?.s2ShowBrushSizePreviewHUD = false
        }
    }

    public func switchSuiteApp(_ app: SuiteAppKind) {
        flushAllSync()
        activeSuiteApp = app
        if workspaceMode == .dualNovelManga {
            workspaceMode = .mangaStudio
        }
    }

    public func toggleDualNovelMangaStudio() {
        flushAllSync()
        if workspaceMode == .dualNovelManga {
            workspaceMode = .mangaStudio
        } else {
            workspaceMode = .dualNovelManga
            if activeSuiteApp == .hub {
                activeSuiteApp = .manga
            }
        }
    }

    public func selectTool(_ tool: S2DrawingToolKind) {
        if !isMangaContext {
            activeSuiteApp = .manga
        }
        s2Tool = tool
        if tool == .eraser {
            s2PresetIndex = 15
        } else if tool == .brush && s2PresetIndex == 15 {
            s2PresetIndex = 0
        }
        lastStatusBanner = "Tool: \(tool.displayName)"
    }

    public func adjustBrushSize(by delta: Double) {
        s2BrushSize = min(max(s2BrushSize + delta, 1.0), 120.0)
    }

    public func setActiveColor(_ rgba: PersistedRGBA) {
        s2ActiveColor = rgba
        if !s2RecentColors.contains(rgba) {
            s2RecentColors.insert(rgba, at: 0)
            if s2RecentColors.count > 12 {
                s2RecentColors.removeLast()
            }
        } else if let idx = s2RecentColors.firstIndex(of: rgba), idx > 0 {
            s2RecentColors.remove(at: idx)
            s2RecentColors.insert(rgba, at: 0)
        }
    }

    public func zoomIn() {
        s2ViewportZoom = min(s2ViewportZoom * 1.25, 8.0)
    }

    public func zoomOut() {
        s2ViewportZoom = max(s2ViewportZoom / 1.25, 0.2)
    }

    public func panCanvas(by delta: CGSize) {
        s2PanOffset = CGSize(
            width: s2PanOffset.width + delta.width,
            height: s2PanOffset.height + delta.height
        )
    }

    public func rotateCanvas(by deltaDeg: Double) {
        var next = s2RotationDeg + deltaDeg
        while next > 180.0 { next -= 360.0 }
        while next < -180.0 { next += 360.0 }
        s2RotationDeg = next
    }

    public func resetRotation() {
        s2RotationDeg = 0.0
    }

    public func resetViewport() {
        s2ViewportZoom = 1.0
        s2PanOffset = .zero
        s2RotationDeg = 0.0
        s2MirrorHorizontal = false
        dispatchCanvasCommand(.resetViewport)
    }

    public func toggleActiveLayerFlag(_ keyPath: WritableKeyPath<CelLayerRowItem, Bool>) {
        guard let idx = selectedCelLayerIndex else { return }
        s2CelLayers[idx][keyPath: keyPath].toggle()
        syncLayerToRust(s2CelLayers[idx])
        refreshCompositeImage()
        markDirtyAndScheduleSave()
    }

    public func setActiveLayerBlendMode(_ mode: LayerBlendMode) {
        guard let idx = selectedCelLayerIndex else { return }
        s2CelLayers[idx].blendMode = mode
        syncLayerToRust(s2CelLayers[idx])
        refreshCompositeImage()
        markDirtyAndScheduleSave()
    }

    public func addLayer(customName: String? = nil) {
        let nextNum = (s2CelLayers.map(\.id).max() ?? 0) + 1
        let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = trimmed.isEmpty ? "Cel_Layer_\(nextNum)" : trimmed
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            let newId = proj.addRasterLayer(name: name, blendMode: .normal, clippingMask: false, isReference: false)
            s2CelLayers.append(CelLayerRowItem(id: newId, name: name))
            s2SelectedLayerId = newId
            refreshCompositeImage()
            markDirtyAndScheduleSave()
            lastStatusBanner = "已新增图层 '\(name)'"
            return
        }
        #endif
        s2CelLayers.append(CelLayerRowItem(id: nextNum, name: name))
        s2SelectedLayerId = nextNum
        markDirtyAndScheduleSave()
    }

    /// Renames any layer by `id` with a user-defined custom name.
    /// The custom name is stored in Undo/Redo checkpoints and `.about-paint-session.json` and is never altered when layers move up or down.
    @discardableResult
    public func renameLayer(id: UInt64, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = s2CelLayers.firstIndex(where: { $0.id == id })
        else { return false }
        let oldName = s2CelLayers[idx].name
        guard oldName != trimmed else { return true }
        beginRasterUndoCheckpoint()
        s2CelLayers[idx].name = trimmed
        markDirtyAndScheduleSave()
        lastStatusBanner = "已将图层 '\(oldName)' 重命名为 '\(trimmed)'"
        return true
    }

    public func duplicateSelectedLayer() {
        guard let idx = selectedCelLayerIndex else { return }
        let src = s2CelLayers[idx]
        let nextNum = (s2CelLayers.map(\.id).max() ?? 0) + 1
        var copyId = nextNum
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            let dup = proj.duplicateLayer(layerId: src.id)
            if dup != 0 {
                copyId = dup
            }
        }
        #endif
        let cloned = CelLayerRowItem(
            id: copyId,
            name: "\(src.name) Copy",
            visible: src.visible,
            isReference: false,
            clippingMask: src.clippingMask,
            alphaLock: src.alphaLock,
            blueSketchTint: src.blueSketchTint,
            blendMode: src.blendMode,
            opacity: src.opacity
        )
        s2CelLayers.insert(cloned, at: idx + 1)
        s2SelectedLayerId = copyId
        syncLayerToRust(cloned)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
    }

    public func deleteSelectedLayer() {
        guard let idx = selectedCelLayerIndex else { return }
        let removed = s2CelLayers[idx]

        // If only 1 layer remains, clear its pixel content so the user's drawing on that layer is deleted cleanly
        if s2CelLayers.count <= 1 {
            clearCurrentLayer()
            lastStatusBanner = "已清空并重置当前唯一图层 '\(removed.name)'"
            return
        }

        let nextIdx = max(0, idx - 1)
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            // Clear pixel tiles first and remove from Rust LayerStack
            _ = proj.clearLayer(layerId: removed.id)
            let didRemoveInRust = proj.deleteLayer(layerId: removed.id)
            s2CelLayers.remove(at: idx)
            s2Strokes.removeAll { $0.layerId == removed.id }
            s2SelectedLayerId = s2CelLayers[nextIdx].id
            if !didRemoveInRust {
                // Reconcile any legacy LayerId mismatch by hiding & clearing orphaned Rust layers
                _ = proj.setLayerFlags(
                    layerId: removed.id,
                    visible: false,
                    alphaLock: false,
                    clippingMask: false,
                    isReference: false,
                    blendMode: .normal,
                    opacity: 0.0,
                    blueSketchTint: false
                )
            }
            refreshCompositeImage()
            markDirtyAndScheduleSave()
            lastStatusBanner = "已删除图层 '\(removed.name)'"
            return
        }
        #endif
        s2CelLayers.remove(at: idx)
        s2Strokes.removeAll { $0.layerId == removed.id }
        s2SelectedLayerId = s2CelLayers[nextIdx].id
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "已删除图层 '\(removed.name)'"
    }

    public func mergeSelectedLayerDown() {
        guard canMergeSelectedLayerDown, let idx = selectedCelLayerIndex else { return }
        let upper = s2CelLayers[idx]
        let targetId = s2CelLayers[idx - 1].id
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            _ = proj.mergeLayerDown(layerId: upper.id)
        }
        #endif
        s2CelLayers.remove(at: idx)
        for i in s2Strokes.indices where s2Strokes[i].layerId == upper.id {
            s2Strokes[i].layerId = targetId
        }
        s2SelectedLayerId = targetId
        refreshCompositeImage()
        markDirtyAndScheduleSave()
    }

    public func moveLayer(id: UInt64, up: Bool) {
        guard let idx = s2CelLayers.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? idx + 1 : idx - 1
        guard s2CelLayers.indices.contains(target) else { return }
        let movedName = s2CelLayers[idx].name
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            _ = proj.moveLayer(layerId: id, up: up)
        }
        #endif
        s2CelLayers.swapAt(idx, target)
        s2SelectedLayerId = id
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = up ? "已上移图层 '\(movedName)'" : "已下移图层 '\(movedName)'"
    }

    public func clearCurrentLayer() {
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            _ = proj.clearLayer(layerId: s2SelectedLayerId)
        }
        #endif
        s2Strokes.removeAll { $0.layerId == s2SelectedLayerId }
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "已清空当前图层内容"
    }

    public func flipSelectedLayer(horizontal: Bool) {
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            beginRasterUndoCheckpoint()
            _ = proj.flipLayer(layerId: s2SelectedLayerId, horizontal: horizontal)
        }
        #endif
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = horizontal ? "Flipped layer horizontally" : "Flipped layer vertically"
    }

    // MARK: - ibisPaint-Aligned Selection & Lasso Operations (Selection / Lasso Fill / Lasso Eraser / Add / Subtract / Drag-to-Move)

    private var activeSelectionBoundsCanvas: CGRect {
        let w = CGFloat(s2CanvasPixelWidth)
        let h = CGFloat(s2CanvasPixelHeight)
        if let normRect = s2SelectionRectNorm {
            return CGRect(
                x: normRect.minX * w,
                y: normRect.minY * h,
                width: max(1, normRect.width * w),
                height: max(1, normRect.height * h)
            )
        } else if !s2SelectionLassoNorm.isEmpty {
            let xs = s2SelectionLassoNorm.map { $0.x * w }
            let ys = s2SelectionLassoNorm.map { $0.y * h }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? w
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? h
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        }
        return CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// Returns `true` if `normPt` (`0..1`) lies inside the currently active Lasso or Marquee selection.
    /// Used in ibisPaint mode so dragging inside an active selection can directly translate the selected pixels.
    public func isNormalizedPointInsideActiveSelection(_ normPt: CGPoint) -> Bool {
        guard s2HasActiveSelection else { return false }
        if let rect = s2SelectionRectNorm {
            return rect.insetBy(dx: -0.015, dy: -0.015).contains(normPt)
        }
        let pts = s2SelectionLassoNorm
        guard pts.count >= 3 else { return false }
        // Exact even-odd ray-casting point-in-polygon test (handle both positive and negative edge dy!)
        var inside = false
        var j = pts.count - 1
        for i in 0..<pts.count {
            let pi = pts[i]
            let pj = pts[j]
            let dy = pj.y - pi.y
            if ((pi.y > normPt.y) != (pj.y > normPt.y)), abs(dy) > 1e-9 {
                let xIntersect = (pj.x - pi.x) * (normPt.y - pi.y) / dy + pi.x
                if normPt.x < xIntersect {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }

    /// Sweeps horizontal scanlines across `bounds` with a hard 192px brush so large selections (> 512px)
    /// are 100% uniformly filled despite Rust's `256px` per-dab radius clamp.
    private func paintUniformFillAcrossSelectionBounds(_ bounds: CGRect, rgba: (UInt8, UInt8, UInt8, UInt8), opacity: Float) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let radius: Float = 160.0
        let stepY = CGFloat(radius * 1.15)
        let minX = Float(max(0.0, bounds.minX - 8.0))
        let maxX = Float(min(CGFloat(s2CanvasPixelWidth), bounds.maxX + 8.0))
        var y = max(0.0, bounds.minY)
        let endY = min(CGFloat(s2CanvasPixelHeight), bounds.maxY)
        var totalTouched = 0
        while true {
            let fy = Float(y)
            totalTouched += proj.paintSegment(
                layerId: s2SelectedLayerId,
                x0: minX,
                y0: fy,
                x1: maxX,
                y1: fy,
                radiusPx: radius,
                hardness: 1.0,
                opacity: opacity,
                rgba: rgba
            )
            if y >= endY { break }
            y = min(endY, y + stepY)
        }
        return totalTouched
        #else
        return 0
        #endif
    }

    /// Sweeps horizontal scanlines across `bounds` with a hard 160px eraser so large selections (> 512px)
    /// are 100% cleanly erased despite Rust's `256px` per-dab radius clamp.
    private func eraseUniformAcrossSelectionBounds(_ bounds: CGRect) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let radius: Float = 160.0
        let stepY = CGFloat(radius * 1.15)
        let minX = Float(max(0.0, bounds.minX - 8.0))
        let maxX = Float(min(CGFloat(s2CanvasPixelWidth), bounds.maxX + 8.0))
        var y = max(0.0, bounds.minY)
        let endY = min(CGFloat(s2CanvasPixelHeight), bounds.maxY)
        var totalTouched = 0
        while true {
            let fy = Float(y)
            totalTouched += proj.eraseSegment(
                layerId: s2SelectedLayerId,
                x0: minX,
                y0: fy,
                x1: maxX,
                y1: fy,
                radiusPx: radius,
                hardness: 1.0,
                opacity: 1.0
            )
            if y >= endY { break }
            y = min(endY, y + stepY)
        }
        return totalTouched
        #else
        return 0
        #endif
    }

    /// Fills the currently active Lasso / Marquee / Magic Wand selection with the active foreground color.
    @discardableResult
    public func fillActiveSelectionWithCurrentColor() -> Int {
        #if canImport(MangaCoreFFI)
        guard rustProject != nil else { return 0 }
        beginRasterUndoCheckpoint()
        let bounds = activeSelectionBoundsCanvas
        let alpha = UInt8(max(1, min(255, Int(round(s2BrushOpacity * 255.0)))))
        let touched = paintUniformFillAcrossSelectionBounds(
            bounds,
            rgba: (s2ActiveColor.r, s2ActiveColor.g, s2ActiveColor.b, alpha),
            opacity: Float(s2BrushOpacity)
        )
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "已在选区内填充颜色 \(s2ActiveColor.hexString) (\(touched) px)"
        return touched
        #else
        return 0
        #endif
    }

    /// Clears/erases only the pixels inside the currently active Lasso / Marquee / Magic Wand selection.
    @discardableResult
    public func eraseActiveSelectionPixels() -> Int {
        #if canImport(MangaCoreFFI)
        guard rustProject != nil else { return 0 }
        beginRasterUndoCheckpoint()
        let bounds = activeSelectionBoundsCanvas
        let touched = eraseUniformAcrossSelectionBounds(bounds)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "已清除选区内像素 (\(touched) px)"
        return touched
        #else
        return 0
        #endif
    }

    /// Combines an existing normalized polygon (`existing`) with a newly drawn polygon (`incoming`)
    /// using `.replace`, `.add` (union via bridge vertices), or `.subtract` (even-odd hole cutout).
    private func combineLassoPolygonsNorm(
        existing: [CGPoint],
        incoming: [CGPoint],
        mode: S2SelectionCombineMode
    ) -> [CGPoint] {
        guard mode != .replace, existing.count >= 3, incoming.count >= 3, let firstExisting = existing.first, let firstIncoming = incoming.first else {
            return incoming
        }
        // In even-odd polygon scanline filling (Rust SelectionMask::from_lasso),
        // connecting two disjoint or hole loops via a zero-width bridge edge (`firstExisting -> firstIncoming -> ... -> firstIncoming -> firstExisting`)
        // creates an exact union for disjoint loops and a cutout hole for interior loops!
        var combined = existing
        combined.append(firstExisting)
        combined.append(contentsOf: incoming)
        combined.append(firstIncoming)
        combined.append(firstExisting)
        return combined
    }

    private func rectToNormPolygon(_ rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]
    }

    /// Expands or contracts the active Lasso or Marquee selection outline and updates the Rust selection mask.
    @discardableResult
    public func adjustActiveSelectionBorder(deltaPx: CGFloat) -> Int {
        let w = CGFloat(max(1, s2CanvasPixelWidth))
        let h = CGFloat(max(1, s2CanvasPixelHeight))
        let dxNorm = deltaPx / w
        let dyNorm = deltaPx / h

        if let rect = s2SelectionRectNorm {
            let newRect = rect.insetBy(dx: -dxNorm, dy: -dyNorm)
            let clamped = CGRect(
                x: min(max(newRect.minX, 0.0), 0.98),
                y: min(max(newRect.minY, 0.0), 0.98),
                width: min(max(newRect.width, 0.01), 1.0 - min(max(newRect.minX, 0.0), 0.98)),
                height: min(max(newRect.height, 0.01), 1.0 - min(max(newRect.minY, 0.0), 0.98))
            )
            let canvasRect = CGRect(
                x: clamped.minX * w,
                y: clamped.minY * h,
                width: clamped.width * w,
                height: clamped.height * h
            )
            return setMarqueeSelection(canvasRect: canvasRect, normRect: clamped, combineMode: .replace)
        } else if s2SelectionLassoNorm.count >= 3 {
            let cx = s2SelectionLassoNorm.map(\.x).reduce(0, +) / CGFloat(s2SelectionLassoNorm.count)
            let cy = s2SelectionLassoNorm.map(\.y).reduce(0, +) / CGFloat(s2SelectionLassoNorm.count)
            var newNorm: [CGPoint] = []
            var newCanvas: [CGPoint] = []
            for pt in s2SelectionLassoNorm {
                let vx = pt.x - cx
                let vy = pt.y - cy
                let len = max(0.0001, hypot(vx, vy))
                let nx = min(max(pt.x + (vx / len) * dxNorm, 0.0), 1.0)
                let ny = min(max(pt.y + (vy / len) * dyNorm, 0.0), 1.0)
                newNorm.append(CGPoint(x: nx, y: ny))
                newCanvas.append(CGPoint(x: nx * w, y: ny * h))
            }
            return setLassoSelection(canvasPoints: newCanvas, normPoints: newNorm, combineMode: .replace, workMode: .selection)
        }
        return s2SelectionPixelCount
    }

    // MARK: - v1.0.0-rc3 Real Rust RGBA8 Raster Painting, Bucket, Eyedropper & Selection

    /// Composites the Rust RGBA8 `LayerStack` into `s2CompositeImage`.
    /// - Parameter interactive: When `true` (mid-stroke at 120–240Hz), throttles full-canvas `CGImage` generation
    ///   to at most ~60 FPS (`16ms`) and skips redundant `@Published` broadcasts so main-thread frame queues never back up.
    public func refreshCompositeImage(interactive: Bool = false) {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return }

        if interactive {
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = now - lastInteractiveCompositeTime
            if elapsed < 0.015 {
                if trailingCompositeTask == nil {
                    let remainingNs = UInt64(max(0.004, 0.016 - elapsed) * 1_000_000_000)
                    trailingCompositeTask = Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: remainingNs)
                        guard let self, !Task.isCancelled else { return }
                        self.trailingCompositeTask = nil
                        self.lastInteractiveCompositeTime = CFAbsoluteTimeGetCurrent()
                        #if canImport(CoreGraphics)
                        if let p = self.rustProject {
                            self.s2CompositeImage = p.makeCGImage(backdropCode: self.s2Backdrop.rustBackdropCode)
                        }
                        #endif
                    }
                }
                return
            }
            lastInteractiveCompositeTime = now
            #if canImport(CoreGraphics)
            s2CompositeImage = proj.makeCGImage(backdropCode: self.s2Backdrop.rustBackdropCode)
            #endif
            return
        }

        trailingCompositeTask?.cancel()
        trailingCompositeTask = nil
        lastInteractiveCompositeTime = CFAbsoluteTimeGetCurrent()

        let w = Int(proj.width)
        let h = Int(proj.height)
        let tiles = proj.allocatedTiles
        let canUndo = proj.canUndoSnapshot
        let canRedo = proj.canRedoSnapshot

        if s2CanvasPixelWidth != w { s2CanvasPixelWidth = w }
        if s2CanvasPixelHeight != h { s2CanvasPixelHeight = h }
        if s2AllocatedTiles != tiles { s2AllocatedTiles = tiles }
        if s2CanUndoRaster != canUndo { s2CanUndoRaster = canUndo }
        if s2CanRedoRaster != canRedo { s2CanRedoRaster = canRedo }
        #if canImport(CoreGraphics)
        s2CompositeImage = proj.makeCGImage(backdropCode: self.s2Backdrop.rustBackdropCode)
        #endif
        #endif
    }

    public func beginRasterUndoCheckpoint() {
        if swiftUndoLayerStack.count >= 40 {
            swiftUndoLayerStack.removeFirst()
        }
        swiftUndoLayerStack.append(SwiftLayerUndoState(layers: s2CelLayers, selectedLayerId: s2SelectedLayerId))
        swiftRedoLayerStack.removeAll()
        #if canImport(MangaCoreFFI)
        rustProject?.pushUndoSnapshot()
        let canUndo = rustProject?.canUndoSnapshot ?? false
        let canRedo = rustProject?.canRedoSnapshot ?? false
        if s2CanUndoRaster != canUndo { s2CanUndoRaster = canUndo }
        if s2CanRedoRaster != canRedo { s2CanRedoRaster = canRedo }
        #endif
    }

    @discardableResult
    public func applyRasterSegment(
        from p0: CGPoint,
        to p1: CGPoint,
        radiusPx: Float,
        hardness: Float,
        opacity: Float
    ) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let touched: Int
        switch s2Tool {
        case .eraser:
            touched = proj.eraseSegment(
                layerId: s2SelectedLayerId,
                x0: Float(p0.x),
                y0: Float(p0.y),
                x1: Float(p1.x),
                y1: Float(p1.y),
                radiusPx: radiusPx,
                hardness: hardness,
                opacity: opacity
            )
        case .smudge:
            touched = proj.smudgeSegment(
                layerId: s2SelectedLayerId,
                x0: Float(p0.x),
                y0: Float(p0.y),
                x1: Float(p1.x),
                y1: Float(p1.y),
                radiusPx: radiusPx,
                strength: max(0.25, opacity)
            )
        case .blur:
            touched = proj.blurSegment(
                layerId: s2SelectedLayerId,
                x0: Float(p0.x),
                y0: Float(p0.y),
                x1: Float(p1.x),
                y1: Float(p1.y),
                radiusPx: radiusPx,
                strength: max(0.35, opacity)
            )
        default:
            touched = proj.paintSegment(
                layerId: s2SelectedLayerId,
                x0: Float(p0.x),
                y0: Float(p0.y),
                x1: Float(p1.x),
                y1: Float(p1.y),
                radiusPx: radiusPx,
                hardness: hardness,
                opacity: opacity,
                rgba: (s2ActiveColor.r, s2ActiveColor.g, s2ActiveColor.b, s2ActiveColor.a)
            )
        }
        return touched
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyBucketFill(canvasX: Int, canvasY: Int) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let cx = UInt32(max(0, min(Int(proj.width) - 1, canvasX)))
        let cy = UInt32(max(0, min(Int(proj.height) - 1, canvasY)))
        beginRasterUndoCheckpoint()
        let filled = proj.closeGapFill(
            layerId: s2SelectedLayerId,
            seedX: cx,
            seedY: cy,
            rgba: (s2ActiveColor.r, s2ActiveColor.g, s2ActiveColor.b, UInt8(max(1, min(255, Int(round(s2BrushOpacity * 255.0)))))),
            closeGapPx: UInt8(max(0, min(15, s2BucketCloseGapPx))),
            expandPx: UInt8(max(0, min(8, s2BucketExpandPx)))
        )
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "Bucket filled \(filled) px (gap=\(s2BucketCloseGapPx)px, expand=+\(s2BucketExpandPx)px)"
        return filled
        #else
        return 0
        #endif
    }

    /// Samples the visible composited pixel (including blue sketch tint, layer blend modes, or paper backdrop)
    /// and sets it as the active foreground color immediately.
    @discardableResult
    public func sampleEyedropper(canvasX: Int, canvasY: Int) -> PersistedRGBA? {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return nil }
        let w = Int(proj.width)
        let h = Int(proj.height)
        guard w > 0, h > 0 else { return nil }
        let cx = max(0, min(w - 1, canvasX))
        let cy = max(0, min(h - 1, canvasY))

        var pickedColor: PersistedRGBA?
        if let raw = proj.sampleEyedropper(x: UInt32(cx), y: UInt32(cy)), raw.3 > 0 {
            pickedColor = PersistedRGBA(r: raw.0, g: raw.1, b: raw.2, a: 255)
        }

        // Fallback when raw layer stack is transparent or blue-sketch-tinted
        if pickedColor == nil || s2CelLayers.contains(where: { $0.visible && $0.blueSketchTint }) {
            let comp = proj.compositeRGBA(backdropCode: s2Backdrop.rustBackdropCode)
            let offset = (cy * w + cx) * 4
            if offset + 3 < comp.count {
                pickedColor = PersistedRGBA(r: comp[offset], g: comp[offset + 1], b: comp[offset + 2], a: 255)
            }
        }

        let color = pickedColor ?? (
            s2Backdrop == .transparentDark
                ? PersistedRGBA(r: 44, g: 46, b: 52, a: 255)
                : PersistedRGBA(r: 255, g: 255, b: 255, a: 255)
        )
        if s2EyedropperPreview != color {
            s2EyedropperPreview = color
        }
        setActiveColor(color)
        lastStatusBanner = "Eyedropper picked \(color.hexString) (RGB \(color.r),\(color.g),\(color.b)) at (\(cx), \(cy))"
        return color
        #else
        return nil
        #endif
    }

    @discardableResult
    public func setMarqueeSelection(
        canvasRect: CGRect,
        normRect: CGRect,
        combineMode: S2SelectionCombineMode? = nil
    ) -> Int {
        let mode = combineMode ?? s2SelectionCombineMode
        if mode != .replace && s2HasActiveSelection {
            let existingPoly = !s2SelectionLassoNorm.isEmpty
                ? s2SelectionLassoNorm
                : (s2SelectionRectNorm.map(rectToNormPolygon) ?? [])
            if existingPoly.count >= 3 {
                let incomingNorm = rectToNormPolygon(normRect)
                let w = CGFloat(max(1, s2CanvasPixelWidth))
                let h = CGFloat(max(1, s2CanvasPixelHeight))
                let incomingCanvas = incomingNorm.map { CGPoint(x: $0.x * w, y: $0.y * h) }
                return setLassoSelection(
                    canvasPoints: incomingCanvas,
                    normPoints: incomingNorm,
                    combineMode: mode,
                    workMode: .selection
                )
            }
        }

        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let x0 = UInt32(max(0, min(Int(proj.width), Int(canvasRect.minX.rounded()))))
        let y0 = UInt32(max(0, min(Int(proj.height), Int(canvasRect.minY.rounded()))))
        let x1 = UInt32(max(0, min(Int(proj.width), Int(canvasRect.maxX.rounded()))))
        let y1 = UInt32(max(0, min(Int(proj.height), Int(canvasRect.maxY.rounded()))))
        let count = proj.setSelectionRect(x0: x0, y0: y0, x1: x1, y1: y1)
        s2SelectionPixelCount = count
        s2HasActiveSelection = count > 0
        s2SelectionRectNorm = count > 0 ? normRect : nil
        s2SelectionLassoNorm = []
        lastStatusBanner = count > 0 ? "矩形选区已选中 \(count) px" : "选区已清除"
        return count
        #else
        s2HasActiveSelection = true
        s2SelectionRectNorm = normRect
        return 1
        #endif
    }

    /// ibisPaint-aligned Lasso execution:
    /// - Supports `.selection` (with `.replace`, `.add`, `.subtract` boolean modes)
    /// - Supports `.lassoFill` (套索填色: immediately fills enclosed polygon with active color & opacity on release!)
    /// - Supports `.lassoEraser` (套索橡皮: immediately erases enclosed polygon on release!)
    @discardableResult
    public func setLassoSelection(
        canvasPoints: [CGPoint],
        normPoints: [CGPoint],
        combineMode: S2SelectionCombineMode? = nil,
        workMode: S2LassoWorkMode? = nil
    ) -> Int {
        guard canvasPoints.count >= 3, normPoints.count >= 3 else { return 0 }
        let activeWorkMode = workMode ?? s2LassoWorkMode
        let activeCombineMode = combineMode ?? s2SelectionCombineMode

        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let w = CGFloat(max(1, s2CanvasPixelWidth))
        let h = CGFloat(max(1, s2CanvasPixelHeight))

        // 1. Immediate ibisPaint "Lasso Fill" (套索填色) or "Lasso Eraser" (套索橡皮)
        if activeWorkMode == .lassoFill || activeWorkMode == .lassoEraser {
            // Preserve any pre-existing selection polygon so temporary lasso fill/erase doesn't destroy user's selection
            let prevHadSelection = s2HasActiveSelection
            let prevRectNorm = s2SelectionRectNorm
            let prevLassoNorm = s2SelectionLassoNorm

            let xs = canvasPoints.map { Float($0.x) }
            let ys = canvasPoints.map { Float($0.y) }
            let maskCount = proj.setSelectionLasso(xs: xs, ys: ys)
            guard maskCount > 0 else {
                if !prevHadSelection { proj.clearSelection() }
                return 0
            }

            let minX = canvasPoints.map(\.x).min() ?? 0
            let maxX = canvasPoints.map(\.x).max() ?? w
            let minY = canvasPoints.map(\.y).min() ?? 0
            let maxY = canvasPoints.map(\.y).max() ?? h
            let loopBounds = CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))

            beginRasterUndoCheckpoint()
            let touched: Int
            if activeWorkMode == .lassoFill {
                let alpha = UInt8(max(1, min(255, Int(round(s2BrushOpacity * 255.0)))))
                touched = paintUniformFillAcrossSelectionBounds(
                    loopBounds,
                    rgba: (s2ActiveColor.r, s2ActiveColor.g, s2ActiveColor.b, alpha),
                    opacity: Float(s2BrushOpacity)
                )
                lastStatusBanner = "套索填色已完成 (\(touched) px · \(s2ActiveColor.hexString))"
            } else {
                touched = eraseUniformAcrossSelectionBounds(loopBounds)
                lastStatusBanner = "套索橡皮已擦除 (\(touched) px)"
            }

            // Restore previous selection state or clear temporary lasso mask
            if prevHadSelection {
                if let r = prevRectNorm {
                    _ = proj.setSelectionRect(
                        x0: UInt32(max(0, min(Int(proj.width), Int((r.minX * w).rounded())))),
                        y0: UInt32(max(0, min(Int(proj.height), Int((r.minY * h).rounded())))),
                        x1: UInt32(max(0, min(Int(proj.width), Int((r.maxX * w).rounded())))),
                        y1: UInt32(max(0, min(Int(proj.height), Int((r.maxY * h).rounded()))))
                    )
                } else if prevLassoNorm.count >= 3 {
                    _ = proj.setSelectionLasso(
                        xs: prevLassoNorm.map { Float($0.x * w) },
                        ys: prevLassoNorm.map { Float($0.y * h) }
                    )
                }
            } else {
                proj.clearSelection()
                s2HasActiveSelection = false
                s2SelectionPixelCount = 0
                s2SelectionRectNorm = nil
                s2SelectionLassoNorm = []
            }

            refreshCompositeImage()
            markDirtyAndScheduleSave()
            return touched
        }

        // 2. Standard ibisPaint Freehand Lasso Selection (with Replace / Add + / Subtract -)
        var finalNormPoints = normPoints
        if activeCombineMode != .replace && s2HasActiveSelection {
            let existingPoly = !s2SelectionLassoNorm.isEmpty
                ? s2SelectionLassoNorm
                : (s2SelectionRectNorm.map(rectToNormPolygon) ?? [])
            if existingPoly.count >= 3 {
                finalNormPoints = combineLassoPolygonsNorm(
                    existing: existingPoly,
                    incoming: normPoints,
                    mode: activeCombineMode
                )
            }
        }

        let xs = finalNormPoints.map { Float($0.x * w) }
        let ys = finalNormPoints.map { Float($0.y * h) }
        let count = proj.setSelectionLasso(xs: xs, ys: ys)
        s2SelectionPixelCount = count
        s2HasActiveSelection = count > 0
        s2SelectionRectNorm = nil
        s2SelectionLassoNorm = count > 0 ? finalNormPoints : []
        let modeTag = activeCombineMode == .replace ? "套索选区" : (activeCombineMode == .add ? "套索加选(+)" : "套索减选(-)")
        lastStatusBanner = count > 0
            ? "\(modeTag)已选中 \(count) px · 可在选区内直接拖动平移，或用上方工具栏填色/擦除/变形"
            : "选区已清除"
        return count
        #else
        s2HasActiveSelection = true
        s2SelectionLassoNorm = normPoints
        return 1
        #endif
    }

    @discardableResult
    public func applyMagicWandSelection(canvasX: Int, canvasY: Int) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let cx = UInt32(max(0, min(Int(proj.width) - 1, canvasX)))
        let cy = UInt32(max(0, min(Int(proj.height) - 1, canvasY)))
        let count = proj.setSelectionMagicWand(
            seedX: cx,
            seedY: cy,
            tolerance: UInt8(max(0, min(255, s2BucketTolerance))),
            useReference: false
        )
        s2SelectionPixelCount = count
        s2HasActiveSelection = count > 0
        s2SelectionRectNorm = count > 0 ? CGRect(x: 0.02, y: 0.02, width: 0.96, height: 0.96) : nil
        s2SelectionLassoNorm = []
        lastStatusBanner = count > 0 ? "Magic Wand selected \(count) px (tol=\(s2BucketTolerance))" : "Magic Wand empty"
        return count
        #else
        return 0
        #endif
    }

    public func selectAllCanvas() {
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            s2SelectionPixelCount = proj.selectAll()
        }
        #endif
        s2HasActiveSelection = true
        s2SelectionRectNorm = CGRect(x: 0, y: 0, width: 1, height: 1)
        s2SelectionLassoNorm = []
        lastStatusBanner = "Selected entire canvas"
    }

    public func clearCanvasSelection() {
        #if canImport(MangaCoreFFI)
        rustProject?.clearSelection()
        #endif
        s2HasActiveSelection = false
        s2SelectionPixelCount = 0
        s2SelectionRectNorm = nil
        s2SelectionLassoNorm = []
        s2LiveLassoNorm = []
        s2LiveMarqueeStartNorm = nil
        s2LiveMarqueeCurrentNorm = nil
        s2LiveTransformPreviewOffsetNorm = .zero
        lastStatusBanner = "Deselected"
    }

    public func invertCanvasSelection() {
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            s2SelectionPixelCount = proj.invertSelection()
            s2HasActiveSelection = s2SelectionPixelCount > 0
            if s2HasActiveSelection && s2SelectionRectNorm == nil && s2SelectionLassoNorm.isEmpty {
                s2SelectionRectNorm = CGRect(x: 0, y: 0, width: 1, height: 1)
            }
            lastStatusBanner = "Inverted selection (\(s2SelectionPixelCount) px)"
        }
        #endif
    }

    @discardableResult
    public func exportCanvasPng(to explicitUrl: URL? = nil, transparentBackground: Bool = false) -> Bool {
        #if canImport(MangaCoreFFI) && canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        guard let proj = rustProject, let data = proj.exportPngData(transparentBackground: transparentBackground) else {
            return false
        }
        if let targetUrl = explicitUrl {
            do {
                try data.write(to: targetUrl, options: .atomic)
                lastStatusBanner = "Exported PNG (\(data.count) B) → \(targetUrl.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #if os(macOS) && canImport(AppKit)
        let panel = NSSavePanel()
        panel.title = "Export Canvas PNG"
        panel.nameFieldStringValue = "\(s3SelectedChapterId)_p001.png"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
                lastStatusBanner = "Exported PNG → \(url.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #elseif os(iOS)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let exportsDir = docs.appendingPathComponent("Exports", isDirectory: true)
            let stamp = Int(Date().timeIntervalSince1970)
            let fileUrl = exportsDir.appendingPathComponent("\(s3SelectedChapterId)_p001_\(stamp).png")
            do {
                try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                try data.write(to: fileUrl, options: .atomic)
                lastStatusBanner = "Saved PNG to Files → Exports/\(fileUrl.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #endif
        #endif
        return false
    }

    @discardableResult
    public func exportCanvasPsd(to explicitUrl: URL? = nil) -> Bool {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return false }
        let data = proj.exportPsdData()
        guard !data.isEmpty else { return false }
        if let targetUrl = explicitUrl {
            do {
                try data.write(to: targetUrl, options: .atomic)
                lastStatusBanner = "Exported PSD (\(data.count) B) → \(targetUrl.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #if os(macOS) && canImport(AppKit)
        let panel = NSSavePanel()
        panel.title = "Export Adobe PSD (8BPS)"
        panel.nameFieldStringValue = "\(s3SelectedChapterId)_p001.psd"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url, options: .atomic)
                lastStatusBanner = "Exported PSD → \(url.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #elseif os(iOS)
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let exportsDir = docs.appendingPathComponent("Exports", isDirectory: true)
            let stamp = Int(Date().timeIntervalSince1970)
            let fileUrl = exportsDir.appendingPathComponent("\(s3SelectedChapterId)_p001_\(stamp).psd")
            do {
                try FileManager.default.createDirectory(at: exportsDir, withIntermediateDirectories: true)
                try data.write(to: fileUrl, options: .atomic)
                lastStatusBanner = "Saved PSD to Files → Exports/\(fileUrl.lastPathComponent)"
                return true
            } catch {
                return false
            }
        }
        #endif
        #endif
        return false
    }

    /// Applies a real Apple Pencil Pro hardware-pressure & tilt modulated stroke segment onto the Rust RGBA8 canvas.
    @discardableResult
    public func applyPencilPressureSegment(
        from p0: CGPoint,
        to p1: CGPoint,
        anchor: CGPoint,
        pressure: Float,
        altitude: Float,
        baseRadiusPx: Float,
        hardness: Float,
        opacity: Float
    ) -> Int {
        let clampedP = min(max(pressure, 0.08), 1.0)
        // G-Pen nonlinear pressure response + subtle chisel widening at low tilt altitude
        let shapedP = powf(clampedP, 0.82)
        let tiltFactor: Float = 1.0 + max(0.0, (1.5708 - min(max(altitude, 0.25), 1.5708)) / 1.5708) * 0.35
        let effectiveRadius = max(0.6, baseRadiusPx * (0.18 + 0.82 * shapedP) * tiltFactor)
        let effectiveOpacity = min(max(opacity * (0.45 + 0.55 * shapedP), 0.05), 1.0)
        return applyRulerAwareRasterSegment(
            from: p0,
            to: p1,
            anchor: anchor,
            radiusPx: effectiveRadius,
            hardness: hardness,
            opacity: effectiveOpacity
        )
    }

    // MARK: - v1.0.0-rc4 Phase 3: 6 FX Filters, Affine Transform, Rulers, Shapes, Screentone, Panels & Bubbles

    @discardableResult
    public func applyRulerAwareRasterSegment(
        from p0: CGPoint,
        to p1: CGPoint,
        anchor: CGPoint,
        radiusPx: Float,
        hardness: Float,
        opacity: Float
    ) -> Int {
        var finalFrom = p0
        var finalTo = p1
        let midX = Float(s2CanvasPixelWidth) * 0.5
        let midY = Float(s2CanvasPixelHeight) * 0.5

        #if canImport(MangaCoreFFI)
        switch s2RulerMode {
        case .parallel:
            let s0 = MangaRulerEngine.transformPoint(
                mode: .parallel,
                paramX: midX, paramY: midY, paramAux: 0.0,
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p0.x), inY: Float(p0.y)
            )
            let s1 = MangaRulerEngine.transformPoint(
                mode: .parallel,
                paramX: midX, paramY: midY, paramAux: 0.0,
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p1.x), inY: Float(p1.y)
            )
            finalFrom = CGPoint(x: CGFloat(s0.0), y: CGFloat(s0.1))
            finalTo = CGPoint(x: CGFloat(s1.0), y: CGFloat(s1.1))
        case .perspective2Pt:
            let horizon = Float(s2CanvasPixelHeight) * 0.45
            let s0 = MangaRulerEngine.transformPoint(
                mode: .perspective2Pt,
                paramX: 0.0, paramY: horizon, paramAux: Float(s2CanvasPixelWidth),
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p0.x), inY: Float(p0.y)
            )
            let s1 = MangaRulerEngine.transformPoint(
                mode: .perspective2Pt,
                paramX: 0.0, paramY: horizon, paramAux: Float(s2CanvasPixelWidth),
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p1.x), inY: Float(p1.y)
            )
            finalFrom = CGPoint(x: CGFloat(s0.0), y: CGFloat(s0.1))
            finalTo = CGPoint(x: CGFloat(s1.0), y: CGFloat(s1.1))
        case .focusLines:
            let s0 = MangaRulerEngine.transformPoint(
                mode: .focusLines,
                paramX: midX, paramY: midY, paramAux: 0.0,
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p0.x), inY: Float(p0.y)
            )
            let s1 = MangaRulerEngine.transformPoint(
                mode: .focusLines,
                paramX: midX, paramY: midY, paramAux: 0.0,
                anchorX: Float(anchor.x), anchorY: Float(anchor.y),
                inX: Float(p1.x), inY: Float(p1.y)
            )
            finalFrom = CGPoint(x: CGFloat(s0.0), y: CGFloat(s0.1))
            finalTo = CGPoint(x: CGFloat(s1.0), y: CGFloat(s1.1))
        default:
            break
        }
        #endif

        var touched = applyRasterSegment(
            from: finalFrom,
            to: finalTo,
            radiusPx: radiusPx,
            hardness: hardness,
            opacity: opacity
        )

        if s2RulerMode == .symmetry {
            let mirrorFrom = CGPoint(x: CGFloat(s2CanvasPixelWidth) - finalFrom.x, y: finalFrom.y)
            let mirrorTo = CGPoint(x: CGFloat(s2CanvasPixelWidth) - finalTo.x, y: finalTo.y)
            touched += applyRasterSegment(
                from: mirrorFrom,
                to: mirrorTo,
                radiusPx: radiusPx,
                hardness: hardness,
                opacity: opacity
            )
        }
        return touched
    }

    @discardableResult
    public func drawRasterShape(
        kind: S2ShapeAssistKind,
        from p0: CGPoint,
        to p1: CGPoint,
        radiusPx: Float,
        hardness: Float,
        opacity: Float
    ) -> Int {
        guard kind != .freehand else { return 0 }
        beginRasterUndoCheckpoint()
        var touched = 0
        switch kind {
        case .line:
            touched += applyRasterSegment(from: p0, to: p1, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
        case .rectangle:
            let minX = min(p0.x, p1.x), maxX = max(p0.x, p1.x)
            let minY = min(p0.y, p1.y), maxY = max(p0.y, p1.y)
            let tl = CGPoint(x: minX, y: minY), tr = CGPoint(x: maxX, y: minY)
            let br = CGPoint(x: maxX, y: maxY), bl = CGPoint(x: minX, y: maxY)
            touched += applyRasterSegment(from: tl, to: tr, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
            touched += applyRasterSegment(from: tr, to: br, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
            touched += applyRasterSegment(from: br, to: bl, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
            touched += applyRasterSegment(from: bl, to: tl, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
        case .ellipse:
            let cx = (p0.x + p1.x) * 0.5
            let cy = (p0.y + p1.y) * 0.5
            let rx = abs(p1.x - p0.x) * 0.5
            let ry = abs(p1.y - p0.y) * 0.5
            let segments = 48
            var prev = CGPoint(x: cx + rx, y: cy)
            for i in 1...segments {
                let angle = Double(i) * (2.0 * Double.pi / Double(segments))
                let next = CGPoint(x: cx + cos(angle) * rx, y: cy + sin(angle) * ry)
                touched += applyRasterSegment(from: prev, to: next, radiusPx: radiusPx, hardness: hardness, opacity: opacity)
                prev = next
            }
        case .freehand:
            break
        }
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "Committed \(kind.displayName) shape (\(touched) px)"
        return touched
    }

    @discardableResult
    public func applyFilterGaussianBlur(radiusPx: Float) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyGaussianBlur(layerId: s2SelectedLayerId, radiusPx: radiusPx)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: Gaussian Blur (r=\(String(format: "%.1f", radiusPx))px, \(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyFilterHsb(hueDeg: Float, satDelta: Float, brightDelta: Float) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyHsb(layerId: s2SelectedLayerId, hueDeg: hueDeg, satDelta: satDelta, brightDelta: brightDelta)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: HSB Adjust (H:\(Int(hueDeg))° S:\(Int(satDelta * 100))% B:\(Int(brightDelta * 100))%)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyFilterBrightnessContrast(brightness: Float, contrast: Float) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyBrightnessContrast(layerId: s2SelectedLayerId, brightness: brightness, contrast: contrast)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: Brightness/Contrast (\(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyFilterExtractLineDrawing(blackThreshold: Float = 0.25, whiteThreshold: Float = 0.80) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyExtractLineDrawing(layerId: s2SelectedLayerId, blackThreshold: blackThreshold, whiteThreshold: whiteThreshold)
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: Extract Line Drawing (\(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyFilterOuterStroke(widthPx: UInt32, color: PersistedRGBA) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyOuterStroke(layerId: s2SelectedLayerId, widthPx: widthPx, rgba: (color.r, color.g, color.b, color.a))
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: Outer Stroke (\(widthPx)px, \(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyFilterDropShadow(dx: Int32, dy: Int32, blurPx: Float, color: PersistedRGBA) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        beginRasterUndoCheckpoint()
        let count = proj.applyDropShadow(layerId: s2SelectedLayerId, dx: dx, dy: dy, blurPx: blurPx, rgba: (color.r, color.g, color.b, color.a))
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "FX: Drop Shadow (dx=\(dx), dy=\(dy), \(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func applyAffineTransform(
        dx: Float,
        dy: Float,
        scaleX: Float,
        scaleY: Float,
        rotDeg: Float,
        selectionOnly: Bool? = nil,
        clearSource: Bool? = nil
    ) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let useSelectionOnly = (selectionOnly ?? s2TransformSelectionOnly) && s2HasActiveSelection
        let useClearSource = clearSource ?? !s2TransformKeepOriginal
        beginRasterUndoCheckpoint()
        let count: Int
        if useSelectionOnly {
            count = proj.transformSelectedPixelsAffine(
                layerId: s2SelectedLayerId,
                dx: dx,
                dy: dy,
                scaleX: scaleX,
                scaleY: scaleY,
                rotDeg: rotDeg,
                clearSource: useClearSource
            )
            transformSelectionOverlayNorm(dx: dx, dy: dy, scaleX: scaleX, scaleY: scaleY, rotDeg: rotDeg)
            let modeLabel = useClearSource ? "选区局部浮动变形" : "选区局部复制盖章"
            lastStatusBanner = "\(modeLabel) (\(count) px)"
        } else {
            count = proj.transformLayerAffine(
                layerId: s2SelectedLayerId,
                dx: dx, dy: dy, scaleX: scaleX, scaleY: scaleY, rotDeg: rotDeg
            )
            lastStatusBanner = "整层变形已应用 (\(count) px)"
        }
        s2LiveTransformPreviewOffsetNorm = .zero
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        return count
        #else
        return 0
        #endif
    }

    /// Keeps the SwiftUI normalized marching-ants selection overlay synced with Rust floating selection transforms.
    private func transformSelectionOverlayNorm(dx: Float, dy: Float, scaleX: Float, scaleY: Float, rotDeg: Float) {
        let cw = max(1.0, Double(s2CanvasPixelWidth))
        let ch = max(1.0, Double(s2CanvasPixelHeight))
        let ndx = Double(dx) / cw
        let ndy = Double(dy) / ch
        let sx = Double(max(0.1, min(8.0, scaleX)))
        let sy = Double(max(0.1, min(8.0, scaleY)))
        let rad = Double(rotDeg) * Double.pi / 180.0
        let cosR = cos(rad)
        let sinR = sin(rad)

        if !s2SelectionLassoNorm.isEmpty {
            let xs = s2SelectionLassoNorm.map { Double($0.x) * cw }
            let ys = s2SelectionLassoNorm.map { Double($0.y) * ch }
            let cx = ((xs.min() ?? 0) + (xs.max() ?? cw)) * 0.5
            let cy = ((ys.min() ?? 0) + (ys.max() ?? ch)) * 0.5
            s2SelectionLassoNorm = s2SelectionLassoNorm.map { pt in
                let lx = (Double(pt.x) * cw - cx) * sx
                let ly = (Double(pt.y) * ch - cy) * sy
                let rx = lx * cosR - ly * sinR + cx + Double(dx)
                let ry = lx * sinR + ly * cosR + cy + Double(dy)
                return CGPoint(
                    x: min(max(rx / cw, 0.0), 1.0),
                    y: min(max(ry / ch, 0.0), 1.0)
                )
            }
        }
        if let rect = s2SelectionRectNorm {
            let newW = min(1.0, max(0.01, rect.width * sx))
            let newH = min(1.0, max(0.01, rect.height * sy))
            let newMidX = min(max(rect.midX + ndx, newW * 0.5), 1.0 - newW * 0.5)
            let newMidY = min(max(rect.midY + ndy, newH * 0.5), 1.0 - newH * 0.5)
            s2SelectionRectNorm = CGRect(
                x: newMidX - newW * 0.5,
                y: newMidY - newH * 0.5,
                width: newW,
                height: newH
            )
        }
    }

    // MARK: - Multi-Canvas Gallery, New Canvas Presets & Photo Import

    public var workspaceGalleryRootDir: URL {
        URL(fileURLWithPath: SuiteSharedWorkspace.defaultProjectDir, isDirectory: true)
            .deletingLastPathComponent()
    }

    public func refreshCanvasGallery() {
        let fm = FileManager.default
        let root = workspaceGalleryRootDir
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        var candidateDirs: [URL] = []
        if let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in entries {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    candidateDirs.append(url)
                }
            }
        }

        let activeUrl = URL(fileURLWithPath: activeProjectDir, isDirectory: true).standardizedFileURL
        if !candidateDirs.contains(where: { $0.standardizedFileURL == activeUrl }) {
            candidateDirs.append(activeUrl)
        }

        var items: [CanvasGalleryItem] = []
        for dirUrl in candidateDirs {
            let stdPath = dirUrl.standardizedFileURL.path
            let sessionUrl = dirUrl.appendingPathComponent(".about-paint-session.json")
            let thumbUrl = dirUrl.appendingPathComponent(".about-paint-thumb.png")
            var width = 800
            var height = 1132
            var layerCount = 3
            var modifiedAt = (try? dirUrl.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

            if let data = try? Data(contentsOf: sessionUrl),
               let session = try? JSONDecoder().decode(ProjectWorkspaceSessionState.self, from: data)
            {
                width = session.s2CanvasPixelWidth ?? 800
                height = session.s2CanvasPixelHeight ?? 1132
                layerCount = max(1, session.s2Layers.count)
                modifiedAt = Date(timeIntervalSince1970: session.savedAtEpochSec)
            }
            let thumbPath = fm.fileExists(atPath: thumbUrl.path) ? thumbUrl.path : nil
            items.append(
                CanvasGalleryItem(
                    id: stdPath,
                    title: dirUrl.lastPathComponent,
                    width: width,
                    height: height,
                    layerCount: layerCount,
                    modifiedAt: modifiedAt,
                    thumbnailPath: thumbPath,
                    isActive: stdPath == activeUrl.path
                )
            )
        }
        items.sort { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.modifiedAt > rhs.modifiedAt
        }
        s2GalleryItems = items
    }

    @discardableResult
    public func createNewCanvasProject(
        title: String,
        width: Int,
        height: Int,
        preset: CanvasPresetKind = .b4PrintManga600Dpi
    ) -> Bool {
        flushAllSync()

        let clampedW = min(max(width, 256), 4096)
        let clampedH = min(max(height, 256), 4096)
        let rawClean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBase = rawClean.isEmpty ? "Canvas" : rawClean.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let root = workspaceGalleryRootDir
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var folderName = safeBase
        var targetUrl = root.appendingPathComponent(folderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: targetUrl.path) {
            let stamp = Int(Date().timeIntervalSince1970) % 100_000
            folderName = "\(safeBase)_\(stamp)"
            targetUrl = root.appendingPathComponent(folderName, isDirectory: true)
        }

        #if canImport(MangaCoreFFI)
        _ = MangaHubProjectBootstrap.initProject(
            parentDir: root.path,
            folderName: folderName,
            author: "Studio Creator"
        )
        #else
        try? FileManager.default.createDirectory(at: targetUrl, withIntermediateDirectories: true)
        #endif

        isRestoring = true
        activeProjectDir = targetUrl.path
        if !recentProjectDirs.contains(targetUrl.path) {
            recentProjectDirs.insert(targetUrl.path, at: 0)
        }
        #if canImport(MangaCoreFFI)
        rustProject = nil
        rustCanvas = nil
        #endif
        #if canImport(CoreGraphics)
        s2ReferenceImage = nil
        s2CompositeImage = nil
        #endif
        s2CanvasPreset = preset
        s2CanvasPixelWidth = clampedW
        s2CanvasPixelHeight = clampedH
        s2CelLayers = []
        s2Strokes = []
        s2UndoneStrokes = []
        swiftUndoLayerStack.removeAll()
        swiftRedoLayerStack.removeAll()
        s2SpeechBubbles = []
        s2HasActiveSelection = false
        s2SelectionPixelCount = 0
        s2SelectionRectNorm = nil
        s2SelectionLassoNorm = []
        s2ViewportZoom = 1.0
        s2PanOffset = .zero
        s2RotationDeg = 0.0
        s2MirrorHorizontal = false
        s2ShowReferenceWindow = false
        isRestoring = false

        ensureRustCanvasAndLayersInitialized()
        loadNovelProseFromDisk()
        flushAllSync()
        refreshCanvasGallery()
        lastStatusBanner = "已新建画布 '\(folderName)' (\(clampedW) × \(clampedH))"
        return true
    }

    public func switchToCanvasProject(dir: String) {
        let stdTarget = URL(fileURLWithPath: dir, isDirectory: true).standardizedFileURL.path
        let stdCurrent = URL(fileURLWithPath: activeProjectDir, isDirectory: true).standardizedFileURL.path
        guard stdTarget != stdCurrent else { return }

        flushAllSync()

        isRestoring = true
        activeProjectDir = stdTarget
        if !recentProjectDirs.contains(stdTarget) {
            recentProjectDirs.insert(stdTarget, at: 0)
        }
        #if canImport(MangaCoreFFI)
        rustProject = nil
        rustCanvas = nil
        #endif
        #if canImport(CoreGraphics)
        s2ReferenceImage = nil
        s2CompositeImage = nil
        #endif
        s2CelLayers = []
        s2Strokes = []
        s2UndoneStrokes = []
        swiftUndoLayerStack.removeAll()
        swiftRedoLayerStack.removeAll()
        s2SpeechBubbles = []
        s2HasActiveSelection = false
        s2SelectionPixelCount = 0
        s2SelectionRectNorm = nil
        s2SelectionLassoNorm = []
        s2CanvasPixelWidth = 800
        s2CanvasPixelHeight = 1132
        isRestoring = false

        restoreProjectSession(from: stdTarget)
        saveGlobalAppStateSync()
        refreshCanvasGallery()
        lastStatusBanner = "已切换画布: \(URL(fileURLWithPath: stdTarget).lastPathComponent) (\(s2CanvasPixelWidth) × \(s2CanvasPixelHeight))"
    }

    @discardableResult
    public func duplicateCanvasProject(dir: String) -> Bool {
        flushAllSync()
        let srcUrl = URL(fileURLWithPath: dir, isDirectory: true)
        let root = workspaceGalleryRootDir
        let stamp = Int(Date().timeIntervalSince1970) % 100_000
        let dstName = "\(srcUrl.lastPathComponent)_Copy_\(stamp)"
        let dstUrl = root.appendingPathComponent(dstName, isDirectory: true)
        do {
            try FileManager.default.copyItem(at: srcUrl, to: dstUrl)
            refreshCanvasGallery()
            lastStatusBanner = "已复制作品 '\(dstName)'"
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func deleteCanvasProject(dir: String) -> Bool {
        refreshCanvasGallery()
        guard s2GalleryItems.count > 1 else {
            lastStatusBanner = "至少保留 1 个活跃画布"
            return false
        }
        let stdTarget = URL(fileURLWithPath: dir, isDirectory: true).standardizedFileURL.path
        let stdCurrent = URL(fileURLWithPath: activeProjectDir, isDirectory: true).standardizedFileURL.path
        if stdTarget == stdCurrent {
            if let fallback = s2GalleryItems.first(where: { $0.id != stdCurrent }) {
                switchToCanvasProject(dir: fallback.id)
            }
        }
        do {
            try FileManager.default.removeItem(atPath: stdTarget)
            recentProjectDirs.removeAll { URL(fileURLWithPath: $0).standardizedFileURL.path == stdTarget }
            refreshCanvasGallery()
            lastStatusBanner = "已删除画布 '\(URL(fileURLWithPath: stdTarget).lastPathComponent)'"
            return true
        } catch {
            return false
        }
    }

    /// Decodes an imported PNG/JPEG photo via ImageIO into an RGBA8 bitmap and blits it aspect-fit onto a new Rust layer.
    @discardableResult
    public func importImageDataAsNewLayer(_ data: Data, layerName: String = "Imported_Photo") -> Bool {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            lastStatusBanner = "无法解码导入的图片文件"
            return false
        }
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 0, srcH > 0 else { return false }

        // Cap imported bitmap decode size to 2048px on longest edge for instant iPad/Mac blit performance
        let maxDecode = 2048.0
        let scaleDown = min(1.0, maxDecode / Double(max(srcW, srcH)))
        let decW = max(1, Int((Double(srcW) * scaleDown).rounded()))
        let decH = max(1, Int((Double(srcH) * scaleDown).rounded()))

        var rgba = [UInt8](repeating: 0, count: decW * decH * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drew = rgba.withUnsafeMutableBytes { rawBuf -> Bool in
            guard let ptr = rawBuf.baseAddress,
                  let ctx = CGContext(
                    data: ptr,
                    width: decW,
                    height: decH,
                    bitsPerComponent: 8,
                    bytesPerRow: decW * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  )
            else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: decW, height: decH))
            return true
        }
        guard drew else { return false }

        // Un-premultiply RGB so Rust straight-RGBA8 compositing preserves exact colors
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let a = Int(rgba[i + 3])
            if a > 0 && a < 255 {
                rgba[i] = UInt8(min(255, Int(rgba[i]) * 255 / a))
                rgba[i + 1] = UInt8(min(255, Int(rgba[i + 1]) * 255 / a))
                rgba[i + 2] = UInt8(min(255, Int(rgba[i + 2]) * 255 / a))
            }
        }

        // Aspect-fit centered inside current canvas
        let cw = Double(max(1, s2CanvasPixelWidth))
        let ch = Double(max(1, s2CanvasPixelHeight))
        let fitScale = min(cw / Double(decW), ch / Double(decH))
        let dstW = max(1, Int((Double(decW) * fitScale).rounded()))
        let dstH = max(1, Int((Double(decH) * fitScale).rounded()))
        let dstX = Int(((cw - Double(dstW)) * 0.5).rounded())
        let dstY = Int(((ch - Double(dstH)) * 0.5).rounded())

        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return false }
        beginRasterUndoCheckpoint()
        let nextNum = (s2CelLayers.map(\.id).max() ?? 0) + 1
        let finalName = "\(layerName)_\(nextNum)"
        let newId = proj.addRasterLayer(name: finalName, blendMode: .normal, clippingMask: false, isReference: false)
        let written = proj.importRgbaToLayer(
            layerId: newId,
            rgba: rgba,
            imgWidth: UInt32(decW),
            imgHeight: UInt32(decH),
            dstX: Int32(dstX),
            dstY: Int32(dstY),
            dstWidth: UInt32(dstW),
            dstHeight: UInt32(dstH)
        )
        s2CelLayers.append(CelLayerRowItem(id: newId, name: finalName, blendMode: .normal, opacity: 1.0))
        s2SelectedLayerId = newId
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "已导入图片至新图层 '\(finalName)' (\(dstW)×\(dstH), \(written) px)"
        return written > 0
        #else
        return false
        #endif
        #else
        return false
        #endif
    }

    /// Loads an imported photo directly into the Floating Reference Window and persists it as `reference_image.png`.
    @discardableResult
    public func importReferenceImageData(_ data: Data) -> Bool {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            lastStatusBanner = "无法解码参考图片"
            return false
        }
        s2ReferenceImage = cgImage
        s2ShowReferenceWindow = true
        let refUrl = URL(fileURLWithPath: activeProjectDir).appendingPathComponent("reference_image.png")
        if let png = encodePngData(from: cgImage) {
            try? png.write(to: refUrl, options: .atomic)
        }
        markDirtyAndScheduleSave()
        lastStatusBanner = "已载入参考图 (\(cgImage.width) × \(cgImage.height))"
        return true
        #else
        return false
        #endif
    }

    public func clearReferenceImage() {
        #if canImport(CoreGraphics)
        s2ReferenceImage = nil
        #endif
        let refUrl = URL(fileURLWithPath: activeProjectDir).appendingPathComponent("reference_image.png")
        try? FileManager.default.removeItem(at: refUrl)
        lastStatusBanner = "已恢复参考浮窗为当前画布总览"
    }

    public func loadReferenceImageFromDisk() {
        #if canImport(CoreGraphics) && canImport(ImageIO)
        let refUrl = URL(fileURLWithPath: activeProjectDir).appendingPathComponent("reference_image.png")
        guard let data = try? Data(contentsOf: refUrl),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            s2ReferenceImage = nil
            return
        }
        s2ReferenceImage = cg
        #endif
    }

    #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
    private func encodePngData(from cgImage: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private func writeGalleryThumbnailIfPossible(to dir: String) {
        guard let cg = s2CompositeImage else { return }
        let maxSide = 256.0
        let scale = min(1.0, maxSide / Double(max(cg.width, cg.height)))
        let tw = max(1, Int((Double(cg.width) * scale).rounded()))
        let th = max(1, Int((Double(cg.height) * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: tw,
            height: th,
            bitsPerComponent: 8,
            bytesPerRow: tw * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: tw, height: th))
        guard let thumbCg = ctx.makeImage(), let png = encodePngData(from: thumbCg) else { return }
        let thumbUrl = URL(fileURLWithPath: dir).appendingPathComponent(".about-paint-thumb.png")
        try? png.write(to: thumbUrl, options: .atomic)
    }
    #endif

    @discardableResult
    public func applyScreentoneFill(lpi: Float? = nil, density: Float? = nil, patternCode: UInt32 = 0) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let useLpi = lpi ?? Float(s2ScreentoneLpi)
        let useDensity = density ?? Float(s2ScreentoneDensity)
        beginRasterUndoCheckpoint()
        let count = proj.applyScreentone(
            layerId: s2SelectedLayerId,
            lpi: useLpi,
            dpi: 300.0,
            angleDeg: 45.0,
            density: useDensity,
            patternCode: patternCode,
            rgba: (s2ActiveColor.r, s2ActiveColor.g, s2ActiveColor.b, 255)
        )
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "Screentone applied (\(Int(useLpi)) LPI, \(Int(useDensity * 100))%, \(count) px)"
        return count
        #else
        return 0
        #endif
    }

    @discardableResult
    public func slicePanelFrame(from p0: CGPoint, to p1: CGPoint, gutterPx: Float? = nil) -> Int {
        #if canImport(MangaCoreFFI)
        guard let proj = rustProject else { return 0 }
        let useGutter = gutterPx ?? Float(s2PanelGutterPx)
        beginRasterUndoCheckpoint()
        let count = proj.sliceAndRasterizePanel(
            layerId: s2SelectedLayerId,
            x0: Float(p0.x),
            y0: Float(p0.y),
            x1: Float(p1.x),
            y1: Float(p1.y),
            gutterPx: useGutter
        )
        s2PanelCount = count
        refreshCompositeImage()
        markDirtyAndScheduleSave()
        lastStatusBanner = "Sliced Manga Panel (\(count) panels total, gutter=\(Int(useGutter))px)"
        return count
        #else
        return 0
        #endif
    }

    public func addSpeechBubble(normX: Double, normY: Double, text: String? = nil, isVertical: Bool? = nil) {
        let verticalDefault = isVertical ?? (activeLocale == .zhHans || activeLocale == .zhHant || activeLocale == .yueHant)
        let defaultText = text ?? (verticalDefault ? "星辉觉醒！" : "Starlight Awakens!")
        s2SpeechBubbles.append(PersistedSpeechBubble(normX: normX, normY: normY, text: defaultText, isVertical: verticalDefault))
        markDirtyAndScheduleSave()
        lastStatusBanner = "Placed Speech Bubble (\(s2SpeechBubbles.count))"
    }

    public func removeSpeechBubble(id: UUID) {
        s2SpeechBubbles.removeAll { $0.id == id }
        markDirtyAndScheduleSave()
    }

    public func dispatchCanvasCommand(_ cmd: CanvasMenuCommand) {
        pendingCanvasCommand = cmd
        s2CanvasActionRevision += 1
        switch cmd {
        case .undo:
            performUndoStroke()
        case .redo:
            performRedoStroke()
        case .clearCurrentLayer:
            clearCurrentLayer()
        case .addLayer:
            addLayer()
        case .duplicateLayer:
            duplicateSelectedLayer()
        case .deleteLayer:
            deleteSelectedLayer()
        case .mergeLayerDown:
            mergeSelectedLayerDown()
        case .flipLayerHorizontal:
            flipSelectedLayer(horizontal: true)
        case .flipLayerVertical:
            flipSelectedLayer(horizontal: false)
        case .deselect:
            clearCanvasSelection()
        case .selectAll:
            selectAllCanvas()
        case .invertSelection:
            invertCanvasSelection()
        case .applyScreentone:
            _ = applyScreentoneFill()
        case .exportPng(let url):
            _ = exportCanvasPng(to: url, transparentBackground: s2Backdrop != .whitePaper)
        case .exportPsd(let url):
            _ = exportCanvasPsd(to: url)
        case .applyFilter(let fx):
            s2PendingFilter = fx
        default:
            break
        }
    }

    public func performUndoStroke() {
        var didUndo = false
        #if canImport(MangaCoreFFI)
        if let proj = rustProject, proj.undoSnapshot() {
            didUndo = true
            if let prevLayerState = swiftUndoLayerStack.popLast() {
                swiftRedoLayerStack.append(SwiftLayerUndoState(layers: s2CelLayers, selectedLayerId: s2SelectedLayerId))
                s2CelLayers = prevLayerState.layers
                s2SelectedLayerId = prevLayerState.selectedLayerId
            }
        }
        if let engine = rustCanvas {
            _ = engine.undo()
        }
        #endif
        if let last = s2Strokes.popLast() {
            s2UndoneStrokes.append(last)
            didUndo = true
        }
        if didUndo {
            refreshCompositeImage()
            markDirtyAndScheduleSave()
            lastStatusBanner = "已撤销上一步 (Undo)"
        }
    }

    public func performRedoStroke() {
        var didRedo = false
        #if canImport(MangaCoreFFI)
        if let proj = rustProject, proj.redoSnapshot() {
            didRedo = true
            if let nextLayerState = swiftRedoLayerStack.popLast() {
                swiftUndoLayerStack.append(SwiftLayerUndoState(layers: s2CelLayers, selectedLayerId: s2SelectedLayerId))
                s2CelLayers = nextLayerState.layers
                s2SelectedLayerId = nextLayerState.selectedLayerId
            }
        }
        if let engine = rustCanvas {
            _ = engine.redo()
        }
        #endif
        if let restored = s2UndoneStrokes.popLast() {
            s2Strokes.append(restored)
            didRedo = true
        }
        if didRedo {
            refreshCompositeImage()
            markDirtyAndScheduleSave()
            lastStatusBanner = "已重做 (Redo)"
        }
    }

    public func syncLayerToRust(_ item: CelLayerRowItem) {
        #if canImport(MangaCoreFFI)
        _ = rustProject?.setLayerFlags(
            layerId: item.id,
            visible: item.visible,
            alphaLock: item.alphaLock,
            clippingMask: item.clippingMask,
            isReference: item.isReference,
            blendMode: item.blendMode,
            opacity: Float(item.opacity),
            blueSketchTint: item.blueSketchTint
        )
        #endif
    }

    // MARK: - Novel Persistence (Real Disk Read/Write)

    public func currentProseRelativePath() -> String {
        "chapters/\(s3SelectedChapterId)/novel/prose/\(s3ActiveProseLocale).md"
    }

    public func loadNovelProseFromDisk() {
        let rel = currentProseRelativePath()
        let abs = URL(fileURLWithPath: activeProjectDir).appendingPathComponent(rel)
        if let text = try? String(contentsOf: abs, encoding: .utf8), !text.isEmpty {
            s3ProseText = text
        } else if s3ProseText.isEmpty {
            s3ProseText = """
            # 第一话 星辉觉醒 / Episode 1: Starlight Awakening

            夜风掠过屋顶的铁艺栏杆，林晓握紧手中微微发烫的星纹钢笔。
            The night breeze swept across the rooftop railing as Lin Xiao gripped the warm starlight nib.
            """
        }
    }

    @discardableResult
    public func saveNovelProseNow(explicitHumanEdit: Bool = true) -> Bool {
        let rel = currentProseRelativePath()
        #if canImport(MangaCoreFFI)
        let ok = MangaNovelMetrics.saveProseAtomic(
            projectDir: activeProjectDir,
            relPath: rel,
            markdown: s3ProseText,
            isLocked: s3HumanLocked,
            explicitHumanEdit: explicitHumanEdit
        )
        if ok {
            lastStatusBanner = "Saved \(rel)"
        }
        return ok
        #else
        let abs = URL(fileURLWithPath: activeProjectDir).appendingPathComponent(rel)
        do {
            try FileManager.default.createDirectory(at: abs.deletingLastPathComponent(), withIntermediateDirectories: true)
            try s3ProseText.write(to: abs, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
        #endif
    }

    // MARK: - Project Switching & Native macOS File Dialogs

    public func openProjectDirectory(_ dir: String) {
        flushAllSync()
        activeProjectDir = dir
        if !recentProjectDirs.contains(dir) {
            recentProjectDirs.insert(dir, at: 0)
            if recentProjectDirs.count > 8 {
                recentProjectDirs.removeLast()
            }
        }
        restoreProjectSession(from: dir)
        saveGlobalAppStateSync()
    }

    public func presentOpenProjectDialog() {
        #if os(macOS) && canImport(AppKit)
        let panel = NSOpenPanel()
        panel.title = "Open CPFF v1.0 Project Folder (.prj)"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            openProjectDirectory(url.path)
        }
        #endif
    }

    public func presentExportEpubDialog() {
        #if os(macOS) && canImport(AppKit)
        let panel = NSSavePanel()
        panel.title = "Export EPUB3 Chapter XHTML"
        panel.nameFieldStringValue = "\(s3SelectedChapterId)_\(s3ActiveProseLocale).xhtml"
        if panel.runModal() == .OK, let url = panel.url {
            #if canImport(MangaCoreFFI)
            let xhtml = MangaPublishingTools.renderEpubXhtml(
                title: s3SelectedChapterId,
                locale: s3ActiveProseLocale,
                markdown: s3ProseText
            )
            try? xhtml.write(to: url, atomically: true, encoding: .utf8)
            lastStatusBanner = "Exported EPUB3 XHTML → \(url.lastPathComponent)"
            #endif
        }
        #endif
    }

    // MARK: - 3-Layer Auto-Save & Crash-Safe Restore

    private static let saveTimestampFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt
    }()

    public func markDirtyAndScheduleSave() {
        if !hasUnsavedChanges {
            hasUnsavedChanges = true
        }
        if saveStatusBadge != "Unsaved…" {
            saveStatusBadge = "Unsaved…"
        }
        scheduleAutoSave()
    }

    public func scheduleAutoSave() {
        guard !isRestoring else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard let self, !Task.isCancelled else { return }
            // Never run disk I/O while a stroke or gesture is actively underway
            while self.isCanvasInteractionActive && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard !Task.isCancelled else { return }
            self.flushAllSync(includeThumbnail: false)
        }
    }

    /// Synchronously flushes Layer A (`.mnga` v2 + `novel/prose/<lang>.md`), Layer B (`.about-paint-session.json`),
    /// and Layer C (`app_state.json`) so closing/quitting (`⌘Q`) NEVER loses work.
    public func flushAllSync(includeThumbnail: Bool = true) {
        guard !isRestoring else { return }
        autoSaveTask?.cancel()

        // Layer A1: Save Rust MNGA0002 full pixel-tile archive
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            _ = proj.saveMngaV2(
                projectDir: activeProjectDir,
                relPath: "chapters/\(s3SelectedChapterId)/manuscript/p001.mnga",
                dpi: 600,
                timelapseEvents: UInt32(s2Strokes.count)
            )
        }
        #endif

        // Layer A2: Save active novel prose atomically (unless human-locked without explicit edit)
        if !s3ProseText.isEmpty && !s3HumanLocked {
            _ = saveNovelProseNow(explicitHumanEdit: true)
        }

        // Layer B: Per-project full workspace session snapshot + lightweight Gallery thumbnail
        saveProjectSessionSync(to: activeProjectDir)
        #if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        if includeThumbnail {
            writeGalleryThumbnailIfPossible(to: activeProjectDir)
        }
        #endif

        // Layer C: Global app state (last opened project + locale + active app)
        saveGlobalAppStateSync()

        if hasUnsavedChanges {
            hasUnsavedChanges = false
        }
        saveStatusBadge = "Saved \(Self.saveTimestampFormatter.string(from: Date()))"
    }

    private func projectSessionUrl(for dir: String) -> URL {
        URL(fileURLWithPath: dir).appendingPathComponent(".about-paint-session.json")
    }

    private func saveGlobalAppStateSync() {
        let state = GlobalAppSessionState(
            lastProjectDir: activeProjectDir,
            recentProjectDirs: recentProjectDirs.isEmpty ? [activeProjectDir] : recentProjectDirs,
            activeSuiteAppRaw: activeSuiteApp.rawValue,
            workspaceModeRaw: workspaceMode.rawValue,
            activeLocaleRaw: activeLocale.rawValue,
            hintModeActive: hintModeActive
        )
        do {
            try FileManager.default.createDirectory(
                at: appStateFileUrl.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: appStateFileUrl, options: .atomic)
        } catch {
            // Non-fatal in restricted sandboxes
        }
    }

    private func saveProjectSessionSync(to dir: String) {
        let session = ProjectWorkspaceSessionState(
            hubSectionRaw: hubSection.rawValue,
            s2Tool: s2Tool,
            s2PresetIndex: s2PresetIndex,
            s2CanvasPresetRaw: s2CanvasPreset.rawValue,
            s2BrushSize: s2BrushSize,
            s2BrushOpacity: s2BrushOpacity,
            s2ForceFade: s2ForceFade,
            s2StabilizerPx: s2StabilizerPx,
            s2BucketCloseGapPx: s2BucketCloseGapPx,
            s2BucketExpandPx: s2BucketExpandPx,
            s2BucketTolerance: s2BucketTolerance,
            s2ViewportZoom: s2ViewportZoom,
            s2PanX: Double(s2PanOffset.width),
            s2PanY: Double(s2PanOffset.height),
            s2RotationDeg: s2RotationDeg,
            s2MirrorHorizontal: s2MirrorHorizontal,
            s2Backdrop: s2Backdrop,
            s2ActiveColor: s2ActiveColor,
            s2RecentColors: s2RecentColors,
            s2RulerModeRaw: s2RulerMode.rawValue,
            s2ShapeAssist: s2ShapeAssist,
            s2ShowBrushDrawer: s2ShowBrushDrawer,
            s2ShowLayerDrawer: s2ShowLayerDrawer,
            s2ShowReferenceWindow: s2ShowReferenceWindow,
            s2SelectedLayerId: s2SelectedLayerId,
            s2Layers: s2CelLayers.map(PersistedLayerRecord.init(from:)),
            s2Strokes: s2Strokes,
            s2SpeechBubbles: s2SpeechBubbles,
            s2ApplePencilOnlyDraw: s2ApplePencilOnlyDraw,
            s2CanvasPixelWidth: s2CanvasPixelWidth,
            s2CanvasPixelHeight: s2CanvasPixelHeight,
            s3SelectedChapterId: s3SelectedChapterId,
            s3ActiveProseLocale: s3ActiveProseLocale,
            s3PaperThemeRaw: s3PaperTheme.rawValue,
            s3ZenMode: s3ZenMode,
            s3ShowOutline: s3ShowOutline,
            s3ShowAiRefDrawer: s3ShowAiRefDrawer,
            s3HumanLocked: s3HumanLocked,
            savedAtEpochSec: Date().timeIntervalSince1970
        )
        do {
            let url = projectSessionUrl(for: dir)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(session)
            try data.write(to: url, options: .atomic)
        } catch {
            // Non-fatal
        }
    }

    private func restoreGlobalAndProjectState(overrideProjectDir: String?) {
        isRestoring = true
        defer { isRestoring = false }

        if let data = try? Data(contentsOf: appStateFileUrl),
           let global = try? JSONDecoder().decode(GlobalAppSessionState.self, from: data)
        {
            if overrideProjectDir == nil, FileManager.default.fileExists(atPath: global.lastProjectDir) {
                activeProjectDir = global.lastProjectDir
            }
            recentProjectDirs = global.recentProjectDirs.filter { FileManager.default.fileExists(atPath: $0) }
            if let app = SuiteAppKind(rawValue: global.activeSuiteAppRaw) {
                activeSuiteApp = app
            }
            if let mode = StudioWorkspaceMode(rawValue: global.workspaceModeRaw) {
                workspaceMode = mode
            }
            if let loc = UiLocaleKind(rawValue: global.activeLocaleRaw) {
                activeLocale = loc
            }
            hintModeActive = global.hintModeActive
        }

        if !recentProjectDirs.contains(activeProjectDir) {
            recentProjectDirs.insert(activeProjectDir, at: 0)
        }

        restoreProjectSession(from: activeProjectDir)
    }

    private func restoreProjectSession(from dir: String) {
        let wasRestoring = isRestoring
        isRestoring = true
        defer { isRestoring = wasRestoring }

        if let data = try? Data(contentsOf: projectSessionUrl(for: dir)),
           let session = try? JSONDecoder().decode(ProjectWorkspaceSessionState.self, from: data)
        {
            hubSection = HubSectionKind(rawValue: session.hubSectionRaw) ?? .overview
            s2Tool = session.s2Tool
            s2PresetIndex = session.s2PresetIndex
            s2CanvasPreset = CanvasPresetKind(rawValue: session.s2CanvasPresetRaw) ?? .b4PrintManga600Dpi
            s2BrushSize = session.s2BrushSize
            s2BrushOpacity = session.s2BrushOpacity
            s2ForceFade = session.s2ForceFade
            s2StabilizerPx = session.s2StabilizerPx
            s2BucketCloseGapPx = session.s2BucketCloseGapPx
            s2BucketExpandPx = session.s2BucketExpandPx
            s2BucketTolerance = session.s2BucketTolerance
            s2ViewportZoom = session.s2ViewportZoom
            s2PanOffset = CGSize(width: session.s2PanX, height: session.s2PanY)
            s2RotationDeg = session.s2RotationDeg
            s2MirrorHorizontal = session.s2MirrorHorizontal
            s2Backdrop = session.s2Backdrop
            s2ActiveColor = session.s2ActiveColor
            if !session.s2RecentColors.isEmpty {
                s2RecentColors = session.s2RecentColors
            }
            s2RulerMode = RulerModeKind(rawValue: session.s2RulerModeRaw) ?? .off
            s2ShapeAssist = session.s2ShapeAssist
            s2ShowBrushDrawer = session.s2ShowBrushDrawer
            s2ShowLayerDrawer = session.s2ShowLayerDrawer
            s2ShowReferenceWindow = session.s2ShowReferenceWindow
            s2CelLayers = session.s2Layers.map { $0.toCelLayerRowItem() }
            s2SelectedLayerId = session.s2SelectedLayerId
            s2Strokes = session.s2Strokes
            s2SpeechBubbles = session.s2SpeechBubbles ?? []
            s2ApplePencilOnlyDraw = session.s2ApplePencilOnlyDraw ?? false
            if let savedW = session.s2CanvasPixelWidth, savedW >= 256 {
                s2CanvasPixelWidth = savedW
            }
            if let savedH = session.s2CanvasPixelHeight, savedH >= 256 {
                s2CanvasPixelHeight = savedH
            }
            s3SelectedChapterId = session.s3SelectedChapterId
            s3ActiveProseLocale = session.s3ActiveProseLocale
            s3PaperTheme = PaperThemeKind(rawValue: session.s3PaperThemeRaw) ?? .warmPaper
            s3ZenMode = session.s3ZenMode
            s3ShowOutline = session.s3ShowOutline
            s3ShowAiRefDrawer = session.s3ShowAiRefDrawer
            s3HumanLocked = session.s3HumanLocked
            saveStatusBadge = "Restored"
        }

        ensureRustCanvasAndLayersInitialized()
        loadReferenceImageFromDisk()
        loadNovelProseFromDisk()
        refreshCanvasGallery()
    }

    public func ensureRustCanvasAndLayersInitialized() {
        #if canImport(MangaCoreFFI)
        if rustCanvas == nil {
            rustCanvas = MangaCanvasEngine(preset: s2CanvasPreset)
        }
        if rustProject == nil, let proj = MangaProjectEngine(width: UInt32(s2CanvasPixelWidth), height: UInt32(s2CanvasPixelHeight)) {
            let loadedMnga = proj.loadMngaV2(
                projectDir: activeProjectDir,
                relPath: "chapters/\(s3SelectedChapterId)/manuscript/p001.mnga"
            )
            if !loadedMnga && s2CelLayers.isEmpty {
                let sketchId = proj.addRasterLayer(name: "Sketch_Rough", blendMode: .normal, clippingMask: false, isReference: false)
                let inkId = proj.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, clippingMask: false, isReference: true)
                let shadowId = proj.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: false, isReference: false)
                _ = proj.setLayerFlags(layerId: sketchId, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .normal, opacity: 0.35, blueSketchTint: true)
                s2CelLayers = [
                    CelLayerRowItem(id: sketchId, name: "Sketch_Rough", blueSketchTint: true, blendMode: .normal, opacity: 0.35),
                    CelLayerRowItem(id: inkId, name: "Ink_Lineart", isReference: true, blendMode: .normal, opacity: 1.0),
                    CelLayerRowItem(id: shadowId, name: "Cel_Shadow", clippingMask: false, blendMode: .multiply, opacity: 0.85),
                ]
                s2SelectedLayerId = inkId
            } else if !s2CelLayers.isEmpty && proj.layerCount == 0 {
                let oldSelected = s2SelectedLayerId
                var newSelected: UInt64?
                for i in s2CelLayers.indices {
                    let item = s2CelLayers[i]
                    let lid = proj.addRasterLayer(
                        name: item.name,
                        blendMode: item.blendMode,
                        clippingMask: item.clippingMask,
                        isReference: item.isReference
                    )
                    _ = proj.setLayerFlags(
                        layerId: lid,
                        visible: item.visible,
                        alphaLock: item.alphaLock,
                        clippingMask: item.clippingMask,
                        isReference: item.isReference,
                        blendMode: item.blendMode,
                        opacity: Float(item.opacity),
                        blueSketchTint: item.blueSketchTint
                    )
                    if item.id == oldSelected {
                        newSelected = lid
                    }
                    s2CelLayers[i].id = lid
                }
                s2SelectedLayerId = newSelected ?? s2CelLayers.last?.id ?? 1
            } else if loadedMnga {
                // Reconcile Swift layer metadata against actual Rust LayerStack loaded from p001.mnga
                if s2CelLayers.isEmpty {
                    let count = max(1, proj.layerCount)
                    s2CelLayers = (1...count).map { i in
                        CelLayerRowItem(id: UInt64(i), name: "Cel_Layer_\(i)")
                    }
                }
                var matchedIds = Set<UInt64>()
                var unmatchedIndices: [Int] = []
                for (idx, item) in s2CelLayers.enumerated() {
                    if proj.setLayerFlags(
                        layerId: item.id,
                        visible: item.visible,
                        alphaLock: item.alphaLock,
                        clippingMask: item.clippingMask,
                        isReference: item.isReference,
                        blendMode: item.blendMode,
                        opacity: Float(item.opacity),
                        blueSketchTint: item.blueSketchTint
                    ) {
                        matchedIds.insert(item.id)
                    } else {
                        unmatchedIndices.append(idx)
                    }
                }
                // Only remap unmatched entries so reordered layers that matched by ID keep their exact stack order & custom names!
                if !unmatchedIndices.isEmpty {
                    var orphanRustIds: [UInt64] = []
                    for candidate in 1...UInt64(max(64, proj.layerCount * 4)) where !matchedIds.contains(candidate) {
                        if proj.setLayerFlags(
                            layerId: candidate,
                            visible: true,
                            alphaLock: false,
                            clippingMask: false,
                            isReference: false,
                            blendMode: .normal,
                            opacity: 1.0,
                            blueSketchTint: false
                        ) {
                            orphanRustIds.append(candidate)
                            if matchedIds.count + orphanRustIds.count >= proj.layerCount {
                                break
                            }
                        }
                    }
                    for (orphanOffset, idx) in unmatchedIndices.enumerated() where orphanOffset < orphanRustIds.count {
                        let rustId = orphanRustIds[orphanOffset]
                        s2CelLayers[idx].id = rustId
                        let row = s2CelLayers[idx]
                        _ = proj.setLayerFlags(
                            layerId: rustId,
                            visible: row.visible,
                            alphaLock: row.alphaLock,
                            clippingMask: row.clippingMask,
                            isReference: row.isReference,
                            blendMode: row.blendMode,
                            opacity: Float(row.opacity),
                            blueSketchTint: row.blueSketchTint
                        )
                    }
                }
                if !s2CelLayers.contains(where: { $0.id == s2SelectedLayerId }) {
                    s2SelectedLayerId = s2CelLayers.last?.id ?? 1
                }
            }
            rustProject = proj
        }
        refreshCompositeImage()
        #else
        if s2CelLayers.isEmpty {
            s2CelLayers = [
                CelLayerRowItem(id: 1, name: "Sketch_Rough", blueSketchTint: true, opacity: 0.35),
                CelLayerRowItem(id: 2, name: "Ink_Lineart", isReference: true),
                CelLayerRowItem(id: 3, name: "Cel_Shadow", clippingMask: true, blendMode: .multiply, opacity: 0.85),
            ]
            s2SelectedLayerId = 2
        }
        #endif
    }
}
#endif
