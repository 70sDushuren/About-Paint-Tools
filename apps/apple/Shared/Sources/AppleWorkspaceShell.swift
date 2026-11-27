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

/// Legacy init descriptor kept for compatibility with existing callers/previews.
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

/// Adaptive root shell shared by iPad, Touchscreen MacBook, and iPhone Duo targets (`v1.0.0-rc2`).
/// Uses `ViewThatFits` + `.fixedSize()` + `.lineLimit(1)` to guarantee **zero text overlap or clipping**
/// across all 5 languages (`en`, `zh-Hans`, `zh-Hant`, `yue-Hant`, `es`) and window widths.
public struct AppleWorkspaceShellView: View {
    @ObservedObject public var controller: StudioWorkspaceController
    @State private var dualSplitNovelFraction: CGFloat = 0.42
    @State private var dualSwapSides: Bool = false

    public init(controller: StudioWorkspaceController) {
        self.controller = controller
    }

    public init(initialState: AppleWorkspaceState) {
        let ctrl = StudioWorkspaceController(platform: initialState.platform)
        ctrl.posture = initialState.posture
        ctrl.workspaceMode = initialState.mode
        ctrl.activeSuiteApp = initialState.activeSuiteApp
        ctrl.hingeAvoidanceWidthPt = initialState.hingeAvoidanceWidthPt
        self.controller = ctrl
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let layout = resolveLayout(width: Float(width), height: Float(height))
            VStack(spacing: 0) {
                topBar(layout: layout, availableWidth: width)
                Divider()
                mainContent(layout: layout, size: proxy.size)
                Divider()
                bottomStatusBar(layout: layout)
            }
            .background(shellChromeBackground)
            .environment(\.locale, Locale(identifier: controller.activeLocale.bcp47))
        }
    }

    // MARK: - Responsive Zero-Overlap Unified Top Bar

    private func topBar(layout: WorkspaceLayoutHintKind, availableWidth: CGFloat) -> some View {
        HStack(spacing: 10) {
            // Left identity cluster (flexible title with strict 1-line tail truncation)
            HStack(spacing: 8) {
                Text(suiteBadgeCode)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(suiteAccentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suiteDisplayTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(isDarkHeader ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if availableWidth >= 1080 {
                        Text(URL(fileURLWithPath: controller.activeProjectDir).lastPathComponent + ".prj")
                            .font(.caption2.monospaced())
                            .foregroundStyle(isDarkHeader ? Color.white.opacity(0.62) : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .layoutPriority(0)
            }

            Spacer(minLength: 8)

            // Center adaptive switcher cluster (ViewThatFits prevents any clipping/overlap!)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    suiteAppSegmentedButtons(compact: false)
                    if layout != .singlePaneCompact {
                        workspaceModeMenu
                    }
                }
                HStack(spacing: 8) {
                    suiteAppSegmentedButtons(compact: true)
                    if layout != .singlePaneCompact {
                        workspaceModeMenu
                    }
                }
                suiteAppMenuFallback
            }
            .layoutPriority(2)

            Spacer(minLength: 8)

            // Right utility cluster (strict fixedSize pills so nothing collides)
            HStack(spacing: 8) {
                Button {
                    controller.flushAllSync()
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(controller.hasUnsavedChanges ? Color.orange : Color.green)
                            .frame(width: 7, height: 7)
                        Text(controller.saveStatusBadge)
                            .font(.caption2.monospaced().bold())
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.16))
                    .foregroundStyle(isDarkHeader ? .white : .primary)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                .help("Save All Work Now (⌘S)")

                // Live 5-Language Switcher
                Menu {
                    ForEach(UiLocaleKind.allCases) { loc in
                        Button {
                            controller.activeLocale = loc
                        } label: {
                            Text(loc == controller.activeLocale ? "✓ \(loc.nativeLabel)" : loc.nativeLabel)
                        }
                    }
                } label: {
                    Text(controller.activeLocale.shortBadge)
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.18))
                        .foregroundStyle(isDarkHeader ? .white : .primary)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Switch App Language")

                // Global `?` Hint Mode toggle
                Button {
                    controller.hintModeActive.toggle()
                } label: {
                    Text(controller.hintModeActive ? "? ON" : "?")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(controller.hintModeActive ? suiteAccentColor : Color.secondary.opacity(0.18))
                        .foregroundStyle(controller.hintModeActive ? .white : (isDarkHeader ? .white : .primary))
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle Icon Hint Inspection Mode")
            }
            .layoutPriority(3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(shellChromeBackground)
    }

    private func suiteAppSegmentedButtons(compact: Bool) -> some View {
        HStack(spacing: 3) {
            suitePillButton(.hub, label: compact ? "S1" : "S1 Hub")
            suitePillButton(.manga, label: compact ? "S2" : "S2 Manga")
            suitePillButton(.novel, label: compact ? "S3" : "S3 Novel")
            dualStudioPillButton(compact: compact)
        }
        .padding(3)
        .background(Color.secondary.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func suitePillButton(_ app: SuiteAppKind, label: String) -> some View {
        let selected = controller.activeSuiteApp == app && controller.workspaceMode != .dualNovelManga
        return Button {
            controller.switchSuiteApp(app)
        } label: {
            Text(label)
                .font(.caption.weight(selected ? .bold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? suiteAccentColor : Color.clear)
                .foregroundStyle(selected ? .white : (isDarkHeader ? Color.white.opacity(0.82) : .primary))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private func dualStudioPillButton(compact: Bool) -> some View {
        let selected = controller.workspaceMode == .dualNovelManga
        return Button {
            controller.toggleDualNovelMangaStudio()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.split.2x1.fill")
                    .font(.caption2)
                Text(compact ? "S2+S3" : "S2+S3 同屏双创")
                    .font(.caption.weight(selected ? .bold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                selected
                    ? LinearGradient(
                        colors: [SuiteColorTokens.novelAccent, SuiteColorTokens.mangaAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color.clear, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            .foregroundStyle(selected ? .white : (isDarkHeader ? Color.white.opacity(0.88) : .primary))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .help("同时打开小说文稿与漫画画布 (Dual Novel + Manga Split Studio)")
    }

    private var suiteAppMenuFallback: some View {
        Menu {
            Button("S1 Hub") { controller.switchSuiteApp(.hub) }
            Button("S2 Manga") { controller.switchSuiteApp(.manga) }
            Button("S3 Novel") { controller.switchSuiteApp(.novel) }
            Divider()
            Button("S2+S3 同屏双创 (Novel + Canvas)") {
                controller.toggleDualNovelMangaStudio()
            }
        } label: {
            Text("\(suiteBadgeCode) ▾")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(suiteAccentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var workspaceModeMenu: some View {
        Menu {
            ForEach(StudioWorkspaceMode.allCases) { mode in
                Button {
                    controller.workspaceMode = mode
                    if mode == .dualNovelManga {
                        controller.activeSuiteApp = .manga
                    }
                } label: {
                    let title = localizedCore(mode.rawValue)
                    Text(controller.workspaceMode == mode ? "✓ \(title)" : title)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.split.2x1")
                    .font(.caption2)
                Text(localizedCore(controller.workspaceMode.rawValue))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.16))
            .foregroundStyle(isDarkHeader ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Main Adaptive Tri-App Stage (Supports Simultaneous Novel + Manga Canvas Split!)

    @ViewBuilder
    private func mainContent(layout: WorkspaceLayoutHintKind, size: CGSize) -> some View {
        if controller.workspaceMode == .dualNovelManga {
            VStack(spacing: 0) {
                dualStudioControlStrip
                Divider()
                if size.width >= 640 {
                    // Landscape or iPad Portrait side-by-side split
                    let novelWidth = max(260, min(size.width - 360, size.width * dualSplitNovelFraction))
                    HStack(spacing: 0) {
                        if !dualSwapSides {
                            NovelStudioView(
                                controller: controller,
                                layout: .singlePaneCompact
                            )
                            .frame(width: novelWidth)

                            dualSplitDivider(totalWidth: size.width, isHorizontalSplit: true)

                            MangaCanvasStageView(
                                controller: controller,
                                layout: .singlePaneCompact
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            MangaCanvasStageView(
                                controller: controller,
                                layout: .singlePaneCompact
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            dualSplitDivider(totalWidth: size.width, isHorizontalSplit: true)

                            NovelStudioView(
                                controller: controller,
                                layout: .singlePaneCompact
                            )
                            .frame(width: novelWidth)
                        }
                    }
                } else {
                    // Compact narrow width: top/bottom vertical split so both Novel and Canvas stay visible
                    let novelHeight = max(180, min(size.height - 260, size.height * dualSplitNovelFraction))
                    VStack(spacing: 0) {
                        NovelStudioView(
                            controller: controller,
                            layout: .singlePaneCompact
                        )
                        .frame(height: novelHeight)

                        Divider()

                        MangaCanvasStageView(
                            controller: controller,
                            layout: .singlePaneCompact
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        } else {
            switch controller.activeSuiteApp {
            case .hub:
                HubWorkspaceView(
                    layout: layout,
                    hintModeActive: controller.hintModeActive,
                    activeProjectDir: $controller.activeProjectDir,
                    externalSection: $controller.hubSection
                ) { targetTool in
                    controller.switchSuiteApp(targetTool)
                }
            case .manga:
                MangaCanvasStageView(
                    controller: controller,
                    layout: layout
                )
            case .novel:
                NovelStudioView(
                    controller: controller,
                    layout: layout
                )
            }
        }
    }

    private var dualStudioControlStrip: some View {
        HStack(spacing: 10) {
            Label("S2+S3 同屏双创模式 (小说文稿 + 漫画画布)", systemImage: "rectangle.split.2x1.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text("比例:")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.75))

                ForEach([("35:65", 0.35), ("42:58", 0.42), ("50:50", 0.50)], id: \.0) { item in
                    let active = abs(dualSplitNovelFraction - CGFloat(item.1)) < 0.03
                    Button(item.0) {
                        dualSplitNovelFraction = CGFloat(item.1)
                    }
                    .font(.caption2.monospaced().bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(active ? SuiteColorTokens.novelAccent : Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }

                Button {
                    dualSwapSides.toggle()
                } label: {
                    Label("左右互换", systemImage: "arrow.left.arrow.right")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    controller.switchSuiteApp(.manga)
                } label: {
                    Label("仅看画布", systemImage: "paintbrush.pointed.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(SuiteColorTokens.mangaAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(SuiteColorTokens.mangaPanel)
    }

    private func dualSplitDivider(totalWidth: CGFloat, isHorizontalSplit: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(SuiteColorTokens.mangaBorder)
                .frame(width: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.45))
                .frame(width: 3, height: 36)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard totalWidth > 400 else { return }
                    let delta = (dualSwapSides ? -value.translation.width : value.translation.width) / totalWidth
                    dualSplitNovelFraction = min(max(dualSplitNovelFraction + delta * 0.25, 0.28), 0.62)
                }
        )
    }

    // MARK: - Non-Overlapping Bottom Status Bar (Replaces Floating Canvas Telemetry)

    private func bottomStatusBar(layout: WorkspaceLayoutHintKind) -> some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text(isRustLinked ? "● Rust FFI" : "● Fallback")
                        .foregroundStyle(isRustLinked ? Color.green : Color.orange)
                    Text("·")
                    Text(layoutName(layout))
                    Text("·")
                    Text("Lang: \(controller.activeLocale.bcp47)")
                    if controller.isMangaContext {
                        Text("·")
                        Text("Tool: \(controller.s2Tool.displayName)")
                        Text("·")
                        Text("Tiles: \(controller.s2AllocatedTiles)")
                        Text("·")
                        Text("Zoom: \(Int(controller.s2ViewportZoom * 100))%")
                    }
                    Text("·")
                    Text("Budget: \(ramBudgetMb(for: controller.activeSuiteApp)) MB")
                }
                .lineLimit(1)
            }
            .layoutPriority(1)

            Text("CPFF v1.0 · MIT · v1.0.0-rc2")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
        }
        .font(.caption2.monospaced())
        .foregroundStyle(isDarkHeader ? Color.white.opacity(0.72) : .secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(shellChromeBackground)
    }

    // MARK: - Helpers

    private func localizedCore(_ key: String) -> String {
        #if canImport(MangaCoreFFI)
        return MangaErgonomicsEngine.translate(key: key, locale: controller.activeLocale)
        #else
        return key
        #endif
    }

    private var isDarkHeader: Bool {
        controller.activeSuiteApp == .manga || controller.workspaceMode == .dualNovelManga
    }

    private var shellChromeBackground: Color {
        isDarkHeader ? SuiteColorTokens.mangaPanel : Color.secondary.opacity(0.05)
    }

    private var isRustLinked: Bool {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.isRustFfiLinked
        #else
        return false
        #endif
    }

    private var suiteBadgeCode: String {
        if controller.workspaceMode == .dualNovelManga {
            return "S2+S3"
        }
        switch controller.activeSuiteApp {
        case .hub: return "S1"
        case .manga: return "S2"
        case .novel: return "S3"
        }
    }

    private var suiteDisplayTitle: String {
        if controller.workspaceMode == .dualNovelManga {
            return "双创同屏 · DracoNib + LitteraCore"
        }
        switch controller.activeSuiteApp {
        case .hub: return "创想空间 · NoemaDock"
        case .manga: return "雕龙 · DracoNib"
        case .novel: return "文心 · LitteraCore"
        }
    }

    private var suiteAccentColor: Color {
        if controller.workspaceMode == .dualNovelManga {
            return SuiteColorTokens.novelAccent
        }
        switch controller.activeSuiteApp {
        case .hub: return SuiteColorTokens.hubAccent
        case .manga: return SuiteColorTokens.mangaAccent
        case .novel: return SuiteColorTokens.novelAccent
        }
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
            platform: controller.platform,
            posture: controller.posture,
            widthDp: width,
            heightDp: height
        )
        #else
        if controller.posture == .foldedCompact || width < 520 { return .singlePaneCompact }
        if controller.posture == .unfoldedDualPane { return .dualPaneAcrossHinge }
        if controller.platform == .macOsTouch && width >= 960 { return .desktopTouchHybrid }
        return .tabletTouchStudio
        #endif
    }

    private func layoutName(_ layout: WorkspaceLayoutHintKind) -> String {
        switch layout {
        case .singlePaneCompact: return "SinglePaneCompact"
        case .tabletTouchStudio: return "TabletTouchStudio"
        case .dualPaneAcrossHinge: return "DualPaneAcrossHinge"
        case .tabletopCanvasTopControlsBottom: return "Tabletop"
        case .desktopTouchHybrid: return "DesktopTouchHybrid"
        }
    }
}
#endif
