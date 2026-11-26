import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Three primary creative studio modes (v1.0):
/// 1. Focus Illustration / Webtoon
/// 2. Manga Studio (panels, vector ink, screentones)
/// 3. Dual Studio (Novel prose + independent Manga canvas + read-only AI reference drawer)
public enum StudioWorkspaceMode: String, CaseIterable, Sendable, Identifiable {
    case focusIllustration = "workspace.focus"
    case mangaStudio = "workspace.manga"
    case dualNovelManga = "workspace.dual_studio"

    public var id: String { rawValue }
}

/// Shared adaptive workspace state synchronized across iPadOS, Touchscreen MacBook, and iPhone Duo.
public struct AppleWorkspaceState: Sendable {
    public var platform: TargetPlatformKind
    public var posture: FoldPostureKind
    public var mode: StudioWorkspaceMode
    public var activeSuiteApp: SuiteAppKind
    public var hingeAvoidanceWidthPt: CGFloat

    public init(
        platform: TargetPlatformKind,
        posture: FoldPostureKind = .flat,
        mode: StudioWorkspaceMode = .mangaStudio,
        activeSuiteApp: SuiteAppKind = .manga,
        hingeAvoidanceWidthPt: CGFloat = 0
    ) {
        self.platform = platform
        self.posture = posture
        self.mode = mode
        self.activeSuiteApp = activeSuiteApp
        self.hingeAvoidanceWidthPt = hingeAvoidanceWidthPt
    }
}

private struct PreviewStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

/// Adaptive root shell shared by iPad, Touchscreen MacBook, and iPhone Duo targets.
/// Connects directly to Rust `core/manga-core` (`MangaCoreFFI`) to validate low-latency
/// sparse tile strokes, CoW undo/redo, Tri-App write isolation, and posture layouts on launch.
public struct AppleWorkspaceShellView: View {
    @State private var state: AppleWorkspaceState
    @State private var strokes: [PreviewStroke] = []
    @State private var undoneStrokes: [PreviewStroke] = []
    @State private var activeStroke: PreviewStroke?
    @State private var allocatedTiles: Int = 0
    @State private var canvasDimensions: String = "6071 × 8598 (B4 600DPI)"
    @State private var rustEngineReady: Bool = false
    @State private var statusMessage: String = "Ready"

    #if canImport(MangaCoreFFI)
    @State private var rustCanvas: MangaCanvasEngine?
    #endif

    public init(initialState: AppleWorkspaceState) {
        self._state = State(initialValue: initialState)
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = resolveLayout(width: Float(proxy.size.width), height: Float(proxy.size.height))
            VStack(spacing: 0) {
                topBar(layout: layout, size: proxy.size)
                Divider()
                mainContent(layout: layout)
                Divider()
                bottomStatusBar(layout: layout)
            }
            .background(appBackgroundColor)
        }
        .onAppear(perform: initializeRustEngine)
    }

    // MARK: - Unified Top Bar

    private func topBar(layout: WorkspaceLayoutHintKind, size: CGSize) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(suiteBadgeCode)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(suiteAccentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(suiteDisplayTitle)
                        .font(.headline)
                    Text("Working Codename · is_final_brand=false")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("Tool", selection: $state.activeSuiteApp) {
                Text("S1 Hub").tag(SuiteAppKind.hub)
                Text("S2 Manga").tag(SuiteAppKind.manga)
                Text("S3 Novel").tag(SuiteAppKind.novel)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            if layout != .singlePaneCompact {
                modePicker
                    .frame(maxWidth: 260)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(rustEngineReady ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(rustEngineReady ? "Rust FFI Live" : "Swift Fallback")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Main Adaptive Stage

    @ViewBuilder
    private func mainContent(layout: WorkspaceLayoutHintKind) -> some View {
        switch state.activeSuiteApp {
        case .hub:
            hubOverviewStage(layout: layout)
        case .manga:
            mangaCanvasStage(layout: layout)
        case .novel:
            novelStudioStage(layout: layout)
        }
    }

    private func mangaCanvasStage(layout: WorkspaceLayoutHintKind) -> some View {
        let isDual = layout == .dualPaneAcrossHinge || state.mode == .dualNovelManga
        return HStack(spacing: isDual ? max(state.hingeAvoidanceWidthPt, 14) : 12) {
            VStack(spacing: 10) {
                HStack {
                    Label("S2 Sparse 256×256 CoW Canvas (\(canvasDimensions))", systemImage: "paintbrush.pointed")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Undo") { performUndo() }
                        .disabled(strokes.isEmpty)
                    Button("Redo") { performRedo() }
                        .disabled(undoneStrokes.isEmpty)
                    Button("Clear") { clearCanvas() }
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )

                    Canvas { context, _ in
                        for stroke in strokes {
                            draw(stroke: stroke, in: &context)
                        }
                        if let activeStroke {
                            draw(stroke: activeStroke, in: &context)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDragChanged(at: value.location)
                            }
                            .onEnded { _ in
                                handleDragEnded()
                            }
                    )

                    Text("Draw here with Trackpad, Mouse, Touch, or Apple Pencil → live Rust tile allocation: \(allocatedTiles) tiles")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }

            if layout != .singlePaneCompact {
                rustDiagnosticsSidebar
                    .frame(width: 270)
            }
        }
        .padding(14)
    }

    private func hubOverviewStage(layout: WorkspaceLayoutHintKind) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("S1 · 创想空间 / NoemaDock (Working Codename)")
                    .font(.title3.bold())
                Text("Standalone RAM Budget: \(ramBudgetMb(for: .hub)) MB · GPU Canvas: Disabled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                writeOwnershipCard(for: .hub)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if layout != .singlePaneCompact {
                rustDiagnosticsSidebar
                    .frame(width: 270)
            }
        }
        .padding(16)
    }

    private func novelStudioStage(layout: WorkspaceLayoutHintKind) -> some View {
        HStack(spacing: max(state.hingeAvoidanceWidthPt, 14)) {
            VStack(alignment: .leading, spacing: 12) {
                Text("S3 · 文心 / LitteraCore (Working Codename)")
                    .font(.title3.bold())
                Text("Standalone RAM Budget: \(ramBudgetMb(for: .novel)) MB · GPU Canvas: Disabled · Human Final Decoupled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                writeOwnershipCard(for: .novel)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if layout != .singlePaneCompact {
                rustDiagnosticsSidebar
                    .frame(width: 270)
            }
        }
        .padding(16)
    }

    private var rustDiagnosticsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rust Core FFI Inspector")
                .font(.headline)

            GroupBox("Runtime Metrics") {
                VStack(alignment: .leading, spacing: 6) {
                    metricRow("FFI Bridge", rustEngineReady ? "MangaCoreFFI ✓" : "Fallback")
                    metricRow("Canvas", canvasDimensions)
                    metricRow("Allocated Tiles", "\(allocatedTiles)")
                    metricRow("S1 Budget", "\(ramBudgetMb(for: .hub)) MB")
                    metricRow("S2 Budget", "\(ramBudgetMb(for: .manga)) MB")
                    metricRow("S3 Budget", "\(ramBudgetMb(for: .novel)) MB")
                }
                .padding(.top, 4)
            }

            writeOwnershipCard(for: state.activeSuiteApp)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func writeOwnershipCard(for app: SuiteAppKind) -> some View {
        let testPaths = [
            "SampleManga.prj",
            "chapters/ch001/manuscript/p001.mnga",
            "chapters/ch001/novel/prose/zh-Hans.md",
            "chapters/ch001/ai_assist/manga_to_novel/draft.md",
        ]
        return GroupBox("CPFF v1.0 Write-Ownership Guard") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(testPaths, id: \.self) { path in
                    let allowed = canWrite(app: app, path: path)
                    HStack {
                        Text(path)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(allowed ? "RW" : "RO")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((allowed ? Color.green : Color.secondary).opacity(0.18))
                            .foregroundStyle(allowed ? Color.green : Color.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private func bottomStatusBar(layout: WorkspaceLayoutHintKind) -> some View {
        HStack {
            Text("Layout: \(layoutName(layout))")
            Text("·")
            Text("Platform: \(platformName(state.platform))")
            Spacer()
            Text("CPFF v1.0 · MIT License · v0.1.0-architecture-baseline")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Rust FFI Stroke & Engine Lifecycle

    private func initializeRustEngine() {
        #if canImport(MangaCoreFFI)
        if rustCanvas == nil, let engine = MangaCanvasEngine(preset: .b4PrintManga600Dpi) {
            rustCanvas = engine
            canvasDimensions = "\(engine.width) × \(engine.height) (B4 600DPI)"
            allocatedTiles = engine.allocatedTiles
            rustEngineReady = true
            statusMessage = "Rust manga-core initialized (0 tiles allocated on empty B4 600DPI canvas)."
        }
        #else
        rustEngineReady = false
        statusMessage = "Running SwiftUI preview fallback (build MangaCore.xcframework for live Rust FFI)."
        #endif
    }

    private func handleDragChanged(at point: CGPoint) {
        if activeStroke == nil {
            activeStroke = PreviewStroke(points: [point], color: .black, lineWidth: 3.0)
            #if canImport(MangaCoreFFI)
            rustCanvas?.beginStroke(radius: 6.0, rgba: (17, 18, 22, 255), isEraser: false, stabilizerRadius: 4.0)
            #endif
        } else {
            activeStroke?.points.append(point)
        }

        #if canImport(MangaCoreFFI)
        let sample = NativeStrokeSample(
            x: Float(point.x),
            y: Float(point.y),
            pressure: 0.8,
            altitude: 1.2,
            azimuth: 0.0,
            rollAngle: 0.0,
            timestampMs: Date().timeIntervalSince1970 * 1000.0,
            isPredicted: false
        )
        rustCanvas?.pushPoints([sample])
        if let engine = rustCanvas {
            allocatedTiles = engine.allocatedTiles
        }
        #endif
    }

    private func handleDragEnded() {
        if let finished = activeStroke {
            strokes.append(finished)
            undoneStrokes.removeAll()
            activeStroke = nil
        }
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            let dirty = engine.endStroke()
            allocatedTiles = engine.allocatedTiles
            statusMessage = "Committed stroke in Rust CoW tiles (\(dirty) dirty, \(allocatedTiles) total allocated)."
        }
        #endif
    }

    private func performUndo() {
        guard let last = strokes.popLast() else { return }
        undoneStrokes.append(last)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.undo()
            allocatedTiles = engine.allocatedTiles
            statusMessage = "Rust TileUndoStack Undo applied (\(allocatedTiles) tiles allocated)."
        }
        #endif
    }

    private func performRedo() {
        guard let restored = undoneStrokes.popLast() else { return }
        strokes.append(restored)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.redo()
            allocatedTiles = engine.allocatedTiles
            statusMessage = "Rust TileUndoStack Redo applied (\(allocatedTiles) tiles allocated)."
        }
        #endif
    }

    private func clearCanvas() {
        strokes.removeAll()
        undoneStrokes.removeAll()
        activeStroke = nil
        #if canImport(MangaCoreFFI)
        rustCanvas = MangaCanvasEngine(preset: .b4PrintManga600Dpi)
        allocatedTiles = rustCanvas?.allocatedTiles ?? 0
        statusMessage = "Canvas reset to 0 allocated sparse tiles."
        #endif
    }

    private func draw(stroke: PreviewStroke, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else { return }
        var path = Path()
        path.move(to: stroke.points[0])
        for pt in stroke.points.dropFirst() {
            path.addLine(to: pt)
        }
        context.stroke(
            path,
            with: .color(stroke.color),
            style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    // MARK: - Helpers

    private var modePicker: some View {
        Picker("Workspace", selection: $state.mode) {
            Text(LocalizedStringKey("workspace.focus")).tag(StudioWorkspaceMode.focusIllustration)
            Text(LocalizedStringKey("workspace.manga")).tag(StudioWorkspaceMode.mangaStudio)
            Text(LocalizedStringKey("workspace.dual_studio")).tag(StudioWorkspaceMode.dualNovelManga)
        }
        .pickerStyle(.segmented)
    }

    private var suiteBadgeCode: String {
        switch state.activeSuiteApp {
        case .hub: return "S1"
        case .manga: return "S2"
        case .novel: return "S3"
        }
    }

    private var suiteDisplayTitle: String {
        switch state.activeSuiteApp {
        case .hub: return "创想空间 · NoemaDock"
        case .manga: return "雕龙 · DracoNib"
        case .novel: return "文心 · LitteraCore"
        }
    }

    private var suiteAccentColor: Color {
        switch state.activeSuiteApp {
        case .hub: return Color(red: 0.31, green: 0.49, blue: 1.0)
        case .manga: return Color(red: 1.0, green: 0.42, blue: 0.29)
        case .novel: return Color(red: 0.18, green: 0.66, blue: 0.55)
        }
    }

    private var appBackgroundColor: Color {
        Color.secondary.opacity(0.04)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced().bold())
        }
    }

    private func canWrite(app: SuiteAppKind, path: String) -> Bool {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.canWrite(app: app, relativePath: path)
        #else
        switch app {
        case .hub: return path.hasSuffix(".prj")
        case .manga: return path.contains("/manuscript/")
        case .novel: return path.contains("/novel/") || path.contains("/ai_assist/manga_to_novel/")
        }
        #endif
    }

    private func ramBudgetMb(for app: SuiteAppKind) -> UInt32 {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.ramBudgetMb(for: app)
        #else
        switch app {
        case .hub: return 200
        case .manga: return 1536
        case .novel: return 120
        }
        #endif
    }

    private func resolveLayout(width: Float, height: Float) -> WorkspaceLayoutHintKind {
        #if canImport(MangaCoreFFI)
        return MangaPlatformLayoutEngine.recommendLayout(
            platform: state.platform,
            posture: state.posture,
            widthDp: width,
            heightDp: height
        )
        #else
        if state.posture == .foldedCompact || width < 520 { return .singlePaneCompact }
        if state.posture == .unfoldedDualPane { return .dualPaneAcrossHinge }
        if state.platform == .macOsTouch && width >= 960 { return .desktopTouchHybrid }
        return .tabletTouchStudio
        #endif
    }

    private func layoutName(_ layout: WorkspaceLayoutHintKind) -> String {
        switch layout {
        case .singlePaneCompact: return "SinglePaneCompact"
        case .tabletTouchStudio: return "TabletTouchStudio"
        case .dualPaneAcrossHinge: return "DualPaneAcrossHinge"
        case .tabletopCanvasTopControlsBottom: return "TabletopCanvasTopControlsBottom"
        case .desktopTouchHybrid: return "DesktopTouchHybrid"
        }
    }

    private func platformName(_ platform: TargetPlatformKind) -> String {
        switch platform {
        case .ipadOs: return "iPadOS"
        case .macOsTouch: return "macOS Touch"
        case .iphoneDuo: return "iPhone Duo"
        case .androidPadFoldable: return "Android Foldable"
        case .windowsTouch: return "Windows Touch"
        case .linuxTouch: return "Linux Touch"
        }
    }
}
#endif
