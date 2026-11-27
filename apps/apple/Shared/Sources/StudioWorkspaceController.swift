import Foundation

#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - ibisPaint-Aligned S2 Tooling, Ruler, Shape & Filter Enums

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
        }
    }

    public var usesBrushDynamics: Bool {
        switch self {
        case .brush, .eraser, .smudge, .blur: return true
        default: return false
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
    @Published public var s2BrushSize: Double = 8.0 { didSet { scheduleAutoSave() } }
    @Published public var s2BrushOpacity: Double = 1.0 { didSet { scheduleAutoSave() } }
    @Published public var s2ForceFade: Bool = true { didSet { scheduleAutoSave() } }
    @Published public var s2StabilizerPx: Double = 6.0 { didSet { scheduleAutoSave() } }
    @Published public var s2BucketCloseGapPx: Int = 3 { didSet { scheduleAutoSave() } }
    @Published public var s2BucketExpandPx: Int = 1 { didSet { scheduleAutoSave() } }
    @Published public var s2BucketTolerance: Int = 24 { didSet { scheduleAutoSave() } }
    @Published public var s2ViewportZoom: Double = 1.0 { didSet { scheduleAutoSave() } }
    @Published public var s2PanOffset: CGSize = .zero { didSet { scheduleAutoSave() } }
    @Published public var s2RotationDeg: Double = 0.0 { didSet { scheduleAutoSave() } }
    @Published public var s2MirrorHorizontal: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2Backdrop: S2CanvasBackdropKind = .whitePaper { didSet { scheduleAutoSave() } }
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
    @Published public var s2ShowBrushDrawer: Bool = true { didSet { scheduleAutoSave() } }
    @Published public var s2ShowLayerDrawer: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2ShowReferenceWindow: Bool = false { didSet { scheduleAutoSave() } }
    @Published public var s2CelLayers: [CelLayerRowItem] = []
    @Published public var s2SelectedLayerId: UInt64 = 2 { didSet { scheduleAutoSave() } }
    @Published public var s2Strokes: [PersistedCanvasStroke] = []
    @Published public var s2UndoneStrokes: [PersistedCanvasStroke] = []
    @Published public var s2HasActiveSelection: Bool = false
    @Published public var s2AllocatedTiles: Int = 0
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
        case applyFilter(S2FilterActionKind)
        case exportPng(URL?)
        case exportPsd(URL?)
    }

    private let appStateFileUrl: URL
    private var autoSaveTask: Task<Void, Never>?
    private var isRestoring: Bool = false

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
        isMangaContext && !s2Strokes.isEmpty
    }

    public var canRedoInCurrentContext: Bool {
        isMangaContext && !s2UndoneStrokes.isEmpty
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
        isMangaContext && s2CelLayers.count > 1 && selectedCelLayerIndex != nil
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

    public func switchSuiteApp(_ app: SuiteAppKind) {
        flushAllSync()
        activeSuiteApp = app
        if workspaceMode == .dualNovelManga && app == .hub {
            workspaceMode = .mangaStudio
        }
    }

    public func selectTool(_ tool: S2DrawingToolKind) {
        if !isMangaContext {
            activeSuiteApp = .manga
        }
        s2Tool = tool
        if tool == .eraser {
            s2PresetIndex = 7
        } else if tool == .brush && s2PresetIndex == 7 {
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
        }
    }

    public func zoomIn() {
        s2ViewportZoom = min(s2ViewportZoom * 1.25, 8.0)
    }

    public func zoomOut() {
        s2ViewportZoom = max(s2ViewportZoom / 1.25, 0.2)
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
        markDirtyAndScheduleSave()
    }

    public func setActiveLayerBlendMode(_ mode: LayerBlendMode) {
        guard let idx = selectedCelLayerIndex else { return }
        s2CelLayers[idx].blendMode = mode
        syncLayerToRust(s2CelLayers[idx])
        markDirtyAndScheduleSave()
    }

    public func addLayer() {
        let nextNum = (s2CelLayers.map(\.id).max() ?? 0) + 1
        let name = "Cel_Layer_\(nextNum)"
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            let newId = proj.addRasterLayer(name: name, blendMode: .normal, clippingMask: false, isReference: false)
            s2CelLayers.append(CelLayerRowItem(id: newId, name: name))
            s2SelectedLayerId = newId
            markDirtyAndScheduleSave()
            return
        }
        #endif
        s2CelLayers.append(CelLayerRowItem(id: nextNum, name: name))
        s2SelectedLayerId = nextNum
        markDirtyAndScheduleSave()
    }

    public func duplicateSelectedLayer() {
        guard let idx = selectedCelLayerIndex else { return }
        let src = s2CelLayers[idx]
        let nextNum = (s2CelLayers.map(\.id).max() ?? 0) + 1
        var copyId = nextNum
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            copyId = proj.addRasterLayer(
                name: "\(src.name) Copy",
                blendMode: src.blendMode,
                clippingMask: src.clippingMask,
                isReference: false
            )
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
        let copiedStrokes = s2Strokes.filter { $0.layerId == src.id }.map { st in
            PersistedCanvasStroke(
                layerId: copyId,
                points: st.points,
                color: st.color,
                opacity: st.opacity,
                isEraser: st.isEraser,
                tool: st.tool
            )
        }
        s2Strokes.append(contentsOf: copiedStrokes)
        s2SelectedLayerId = copyId
        syncLayerToRust(cloned)
        markDirtyAndScheduleSave()
    }

    public func deleteSelectedLayer() {
        guard canDeleteSelectedLayer, let idx = selectedCelLayerIndex else { return }
        let removed = s2CelLayers.remove(at: idx)
        s2Strokes.removeAll { $0.layerId == removed.id }
        let nextIdx = max(0, idx - 1)
        s2SelectedLayerId = s2CelLayers[nextIdx].id
        markDirtyAndScheduleSave()
    }

    public func mergeSelectedLayerDown() {
        guard canMergeSelectedLayerDown, let idx = selectedCelLayerIndex else { return }
        let upper = s2CelLayers.remove(at: idx)
        let targetId = s2CelLayers[idx - 1].id
        for i in s2Strokes.indices where s2Strokes[i].layerId == upper.id {
            s2Strokes[i].layerId = targetId
        }
        s2SelectedLayerId = targetId
        markDirtyAndScheduleSave()
    }

    public func moveLayer(id: UInt64, up: Bool) {
        guard let idx = s2CelLayers.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? idx + 1 : idx - 1
        guard s2CelLayers.indices.contains(target) else { return }
        s2CelLayers.swapAt(idx, target)
        markDirtyAndScheduleSave()
    }

    public func clearCurrentLayer() {
        s2Strokes.removeAll { $0.layerId == s2SelectedLayerId }
        markDirtyAndScheduleSave()
        dispatchCanvasCommand(.clearCurrentLayer)
    }

    public func dispatchCanvasCommand(_ cmd: CanvasMenuCommand) {
        pendingCanvasCommand = cmd
        s2CanvasActionRevision += 1
        switch cmd {
        case .undo:
            performUndoStroke()
        case .redo:
            performRedoStroke()
        case .addLayer:
            addLayer()
        case .duplicateLayer:
            duplicateSelectedLayer()
        case .deleteLayer:
            deleteSelectedLayer()
        case .mergeLayerDown:
            mergeSelectedLayerDown()
        case .deselect:
            s2HasActiveSelection = false
        case .selectAll:
            s2HasActiveSelection = true
        default:
            break
        }
    }

    public func performUndoStroke() {
        guard let last = s2Strokes.popLast() else { return }
        s2UndoneStrokes.append(last)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.undo()
            s2AllocatedTiles = engine.allocatedTiles
        }
        #endif
        markDirtyAndScheduleSave()
    }

    public func performRedoStroke() {
        guard let restored = s2UndoneStrokes.popLast() else { return }
        s2Strokes.append(restored)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.redo()
            s2AllocatedTiles = engine.allocatedTiles
        }
        #endif
        markDirtyAndScheduleSave()
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

    public func markDirtyAndScheduleSave() {
        hasUnsavedChanges = true
        saveStatusBadge = "Unsaved…"
        scheduleAutoSave()
    }

    public func scheduleAutoSave() {
        guard !isRestoring else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.flushAllSync()
        }
    }

    /// Synchronously flushes Layer A (`.mnga` v2 + `novel/prose/<lang>.md`), Layer B (`.about-paint-session.json`),
    /// and Layer C (`app_state.json`) so closing/quitting (`⌘Q`) NEVER loses work.
    public func flushAllSync() {
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

        // Layer B: Per-project full workspace session snapshot
        saveProjectSessionSync(to: activeProjectDir)

        // Layer C: Global app state (last opened project + locale + active app)
        saveGlobalAppStateSync()

        hasUnsavedChanges = false
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        saveStatusBadge = "Saved \(fmt.string(from: Date()))"
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
        loadNovelProseFromDisk()
    }

    public func ensureRustCanvasAndLayersInitialized() {
        #if canImport(MangaCoreFFI)
        if rustCanvas == nil {
            rustCanvas = MangaCanvasEngine(preset: s2CanvasPreset)
            s2AllocatedTiles = rustCanvas?.allocatedTiles ?? 0
        }
        if rustProject == nil, let proj = MangaProjectEngine(preset: s2CanvasPreset) {
            let loadedMnga = proj.loadMngaV2(
                projectDir: activeProjectDir,
                relPath: "chapters/\(s3SelectedChapterId)/manuscript/p001.mnga"
            )
            if !loadedMnga && s2CelLayers.isEmpty {
                let sketchId = proj.addRasterLayer(name: "Sketch_Rough", blendMode: .normal, clippingMask: false, isReference: false)
                let inkId = proj.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, clippingMask: false, isReference: true)
                let shadowId = proj.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: true, isReference: false)
                _ = proj.setLayerFlags(layerId: sketchId, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .normal, opacity: 0.35, blueSketchTint: true)
                s2CelLayers = [
                    CelLayerRowItem(id: sketchId, name: "Sketch_Rough", blueSketchTint: true, blendMode: .normal, opacity: 0.35),
                    CelLayerRowItem(id: inkId, name: "Ink_Lineart", isReference: true, blendMode: .normal, opacity: 1.0),
                    CelLayerRowItem(id: shadowId, name: "Cel_Shadow", clippingMask: true, blendMode: .multiply, opacity: 0.85),
                ]
                s2SelectedLayerId = inkId
            } else if !s2CelLayers.isEmpty && proj.layerCount == 0 {
                for item in s2CelLayers {
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
                }
            }
            rustProject = proj
        }
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
