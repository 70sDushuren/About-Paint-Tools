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

/// Adaptive root shell shared by iPad, Touchscreen MacBook, and iPhone Duo targets (`v0.2.2`).
/// Composes the three modular Tri-App workspaces (`S1` Hub / `S2` Manga / `S3` Novel) with
/// unified Icon-First + 4-Element Hint Mode (`?`) and live Rust `MangaCoreFFI` wiring.
public struct AppleWorkspaceShellView: View {
    @State private var state: AppleWorkspaceState
    @State private var hintModeActive: Bool = false
    @State private var activeProjectDir: String

    public init(initialState: AppleWorkspaceState) {
        self._state = State(initialValue: initialState)
        self._activeProjectDir = State(initialValue: SuiteSharedWorkspace.bootstrapDefaultWorkspaceIfNeeded())
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = resolveLayout(width: Float(proxy.size.width), height: Float(proxy.size.height))
            VStack(spacing: 0) {
                topBar(layout: layout)
                Divider()
                mainContent(layout: layout)
                Divider()
                bottomStatusBar(layout: layout)
            }
            .background(shellChromeBackground)
        }
    }

    // MARK: - Unified Top Bar

    private func topBar(layout: WorkspaceLayoutHintKind) -> some View {
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
                        .foregroundStyle(isDarkHeader ? .white : .primary)
                    Text("Working Codename · is_final_brand=false")
                        .font(.caption2)
                        .foregroundStyle(isDarkHeader ? Color.white.opacity(0.6) : .secondary)
                }
            }

            Spacer()

            Picker("Tool", selection: $state.activeSuiteApp) {
                Text("S1 Hub").tag(SuiteAppKind.hub)
                Text("S2 Manga").tag(SuiteAppKind.manga)
                Text("S3 Novel").tag(SuiteAppKind.novel)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 270)

            if layout != .singlePaneCompact {
                modePicker
                    .frame(maxWidth: 250)
            }

            // Decision #2: Global `?` Hint Mode toggle (tap any rail icon to inspect its 4-element Hint card)
            Button {
                hintModeActive.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text("?")
                        .font(.caption.bold())
                    if layout != .singlePaneCompact {
                        Text(hintModeActive ? "Hint ON" : "Hint")
                            .font(.caption.bold())
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(hintModeActive ? suiteAccentColor : Color.secondary.opacity(0.18))
                .foregroundStyle(hintModeActive ? .white : (isDarkHeader ? .white : .primary))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle Icon Hint Inspection Mode")

            HStack(spacing: 6) {
                Circle()
                    .fill(isRustLinked ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isRustLinked ? "Rust FFI" : "Fallback")
                    .font(.caption.monospaced())
                    .foregroundStyle(isDarkHeader ? Color.white.opacity(0.7) : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(shellChromeBackground)
    }

    // MARK: - Main Adaptive Tri-App Stage

    @ViewBuilder
    private func mainContent(layout: WorkspaceLayoutHintKind) -> some View {
        if state.mode == .dualNovelManga && layout != .singlePaneCompact {
            HStack(spacing: max(state.hingeAvoidanceWidthPt, 1)) {
                NovelStudioView(
                    layout: .singlePaneCompact,
                    hintModeActive: hintModeActive,
                    hingeAvoidanceWidthPt: state.hingeAvoidanceWidthPt,
                    activeProjectDir: activeProjectDir
                )
                .frame(minWidth: 320, maxWidth: .infinity)

                MangaCanvasStageView(
                    layout: .singlePaneCompact,
                    hintModeActive: hintModeActive,
                    hingeAvoidanceWidthPt: state.hingeAvoidanceWidthPt
                )
                .frame(minWidth: 380, maxWidth: .infinity)
            }
        } else {
            switch state.activeSuiteApp {
            case .hub:
                HubWorkspaceView(
                    layout: layout,
                    hintModeActive: hintModeActive,
                    activeProjectDir: $activeProjectDir
                ) { targetTool in
                    state.activeSuiteApp = targetTool
                }
            case .manga:
                MangaCanvasStageView(
                    layout: layout,
                    hintModeActive: hintModeActive,
                    hingeAvoidanceWidthPt: state.hingeAvoidanceWidthPt
                )
            case .novel:
                NovelStudioView(
                    layout: layout,
                    hintModeActive: hintModeActive,
                    hingeAvoidanceWidthPt: state.hingeAvoidanceWidthPt,
                    activeProjectDir: activeProjectDir
                )
            }
        }
    }

    // MARK: - Bottom Status Bar

    private func bottomStatusBar(layout: WorkspaceLayoutHintKind) -> some View {
        HStack {
            Text("Layout: \(layoutName(layout))")
            Text("·")
            Text("Platform: \(platformName(state.platform))")
            Text("·")
            Text("Budget: \(ramBudgetMb(for: state.activeSuiteApp)) MB")
            Spacer()
            Text("CPFF v1.0 · MIT · v0.4.0 / T0.4-S4")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(isDarkHeader ? Color.white.opacity(0.65) : .secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(shellChromeBackground)
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

    private var isDarkHeader: Bool {
        state.activeSuiteApp == .manga && state.mode != .dualNovelManga
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
