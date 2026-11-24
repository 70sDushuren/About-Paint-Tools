import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Three primary creative studio modes (v1.0):
/// 1. Focus Illustration / Webtoon
/// 2. Manga Studio (panels, vector ink, screentones)
/// 3. Dual Studio (Novel prose + independent Manga canvas + read-only AI reference drawer)
public enum StudioWorkspaceMode: String, CaseIterable, Sendable {
    case focusIllustration = "workspace.focus"
    case mangaStudio = "workspace.manga"
    case dualNovelManga = "workspace.dual_studio"
}

/// Shared adaptive workspace state synchronized across iPadOS, Touchscreen MacBook, and iPhone Duo.
public struct AppleWorkspaceState: Sendable {
    public var platform: TargetPlatformKind
    public var posture: FoldPostureKind
    public var mode: StudioWorkspaceMode
    public var hingeAvoidanceWidthPt: CGFloat

    public init(
        platform: TargetPlatformKind,
        posture: FoldPostureKind = .flat,
        mode: StudioWorkspaceMode = .mangaStudio,
        hingeAvoidanceWidthPt: CGFloat = 0
    ) {
        self.platform = platform
        self.posture = posture
        self.mode = mode
        self.hingeAvoidanceWidthPt = hingeAvoidanceWidthPt
    }
}

/// Adaptive root shell skeleton shared by iPad, Touchscreen MacBook, and iPhone Duo targets.
public struct AppleWorkspaceShellView: View {
    @State private var state: AppleWorkspaceState

    public init(initialState: AppleWorkspaceState) {
        self._state = State(initialValue: initialState)
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = resolveLayout(width: Float(proxy.size.width), height: Float(proxy.size.height))
            Group {
                switch layout {
                case .singlePaneCompact:
                    // Folded iPhone Duo or 1/3 iPad Split View: focus on quick sketch, novel prose, or voice continuity
                    VStack(spacing: 8) {
                        modePicker
                        canvasOrNovelPlaceholder(title: "Compact Studio (Novel / Quick Sketch / Voice Continuity)")
                    }
                    .padding(8)
                case .dualPaneAcrossHinge:
                    // Unfolded iPhone Duo: left pane = Novel/Outline/AI Ref, hinge gutter, right pane = Manga Canvas
                    HStack(spacing: max(state.hingeAvoidanceWidthPt, 16)) {
                        canvasOrNovelPlaceholder(title: "Novel Final & Read-Only AI Ref")
                        canvasOrNovelPlaceholder(title: "Manga Canvas (Independent Final)")
                    }
                    .padding(10)
                case .desktopTouchHybrid:
                    // Touchscreen MacBook: full desktop toolbar + enlarged touch-friendly inspector hit targets
                    VStack(spacing: 0) {
                        HStack {
                            modePicker
                            Spacer()
                            Text("Touchscreen MacBook Hybrid")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        canvasOrNovelPlaceholder(title: "Metal Canvas + Keyboard & Direct Touch")
                    }
                case .tabletTouchStudio, .tabletopCanvasTopControlsBottom:
                    // Standard iPadOS full-screen touch/Pencil Pro studio
                    VStack(spacing: 8) {
                        modePicker
                        canvasOrNovelPlaceholder(title: "iPadOS ProMotion Metal Canvas")
                    }
                    .padding(12)
                }
            }
        }
    }

    private var modePicker: some View {
        Picker("Workspace", selection: $state.mode) {
            Text(LocalizedStringKey("workspace.focus")).tag(StudioWorkspaceMode.focusIllustration)
            Text(LocalizedStringKey("workspace.manga")).tag(StudioWorkspaceMode.mangaStudio)
            Text(LocalizedStringKey("workspace.dual_studio")).tag(StudioWorkspaceMode.dualNovelManga)
        }
        .pickerStyle(.segmented)
    }

    private func canvasOrNovelPlaceholder(title: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.secondary.opacity(0.12))
            .overlay(Text(title).font(.footnote).foregroundStyle(.secondary))
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
}
#endif
