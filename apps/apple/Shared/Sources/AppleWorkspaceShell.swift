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
            let layout = resolveLayout(width: Float(width), height: Float(proxy.size.height))
            VStack(spacing: 0) {
                topBar(layout: layout, availableWidth: width)
                Divider()
                mainContent(layout: layout)
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

    private var suiteAppMenuFallback: some View {
        Menu {
            Button("S1 Hub") { controller.switchSuiteApp(.hub) }
            Button("S2 Manga") { controller.switchSuiteApp(.manga) }
            Button("S3 Novel") { controller.switchSuiteApp(.novel) }
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

    // MARK: - Main Adaptive Tri-App Stage

    @ViewBuilder
    private func mainContent(layout: WorkspaceLayoutHintKind) -> some View {
        if controller.workspaceMode == .dualNovelManga && layout != .singlePaneCompact {
            HStack(spacing: max(controller.hingeAvoidanceWidthPt, 1)) {
                NovelStudioView(
                    controller: controller,
                    layout: .singlePaneCompact
                )
                .frame(minWidth: 320, maxWidth: .infinity)

                MangaCanvasStageView(
                    controller: controller,
                    layout: .singlePaneCompact
                )
                .frame(minWidth: 420, maxWidth: .infinity)
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
        controller.activeSuiteApp == .manga && controller.workspaceMode != .dualNovelManga
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
        switch controller.activeSuiteApp {
        case .hub: return "S1"
        case .manga: return "S2"
        case .novel: return "S3"
        }
    }

    private var suiteDisplayTitle: String {
        switch controller.activeSuiteApp {
        case .hub: return "创想空间 · NoemaDock"
        case .manga: return "雕龙 · DracoNib"
        case .novel: return "文心 · LitteraCore"
        }
    }

    private var suiteAccentColor: Color {
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
