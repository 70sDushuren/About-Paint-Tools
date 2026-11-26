import Foundation

#if canImport(SwiftUI)
import SwiftUI

public enum PaperThemeKind: String, CaseIterable, Sendable, Identifiable {
    case warmPaper = "Warm Paper"
    case sepia = "Sepia"
    case nightInk = "Night Ink"

    public var id: String { rawValue }

    public var background: Color {
        switch self {
        case .warmPaper: return SuiteColorTokens.novelWarmPaper
        case .sepia: return SuiteColorTokens.novelSepia
        case .nightInk: return SuiteColorTokens.novelNightInk
        }
    }

    public var chromeBackground: Color {
        switch self {
        case .warmPaper: return Color(red: 0.945, green: 0.937, blue: 0.918)
        case .sepia: return Color(red: 0.914, green: 0.882, blue: 0.820)
        case .nightInk: return Color(red: 0.129, green: 0.141, blue: 0.169)
        }
    }

    public var textColor: Color {
        switch self {
        case .warmPaper, .sepia: return Color(red: 0.14, green: 0.15, blue: 0.17)
        case .nightInk: return Color(red: 0.90, green: 0.91, blue: 0.93)
        }
    }

    public var isDark: Bool { self == .nightInk }
}

private struct NovelChapterItem: Identifiable {
    let id: String
    let title: String
    let hasDivergence: Bool
    let humanLocked: Bool
}

/// `S3 v0.3.2` — `文心 / LitteraCore` (Working Codename) light-novel studio:
/// 「素笺」3 eye-friendly themes (Warm Paper / Sepia / Night Ink) + Calm Sage (#2FA88B) +
/// Zen mode + live `< 300ms` disk revision-hash watcher for RO `Story Bible` & `CPFF TOC` +
/// live Rust `MangaNovelMetrics.countUnits` + dashed read-only AI reference drawer.
public struct NovelStudioView: View {
    public let layout: WorkspaceLayoutHintKind
    public let hintModeActive: Bool
    public let hingeAvoidanceWidthPt: CGFloat
    public let activeProjectDir: String

    @State private var theme: PaperThemeKind = .warmPaper
    @State private var zenMode: Bool = false
    @State private var showOutline: Bool = true
    @State private var showAiRefDrawer: Bool = false
    @State private var selectedChapterId: String = "ch001"
    @State private var liveBibleCharacters: [StoryBibleCharacterSummary] = []
    @State private var liveTocEntries: [ProjectTocEntrySummary] = []
    @State private var observedRevisionHash: UInt64 = 0
    @State private var lastHotReloadMs: Double = 0.0
    @State private var proseText: String = """
    # 第一话 星辉觉醒 / Episode 1: Starlight Awakening

    夜风掠过屋顶的铁艺栏杆，林晓握紧手中微微发烫的星纹钢笔。
    The night breeze swept across the rooftop railing as Lin Xiao gripped the warm starlight nib.

    “如果这一页画不下所有的回忆，那就把余下的故事写进小说里吧。”
    """
    @State private var aiReferenceDraft: String = """
    [AI Reference Draft · role="ai_reference_only"]
    Suggested sensory detail from S2 Manga Panel #3:
    - Rooftop neon glare reflecting off wet rain tiles
    - Starlight crest pulsing softly before the first ink stroke lands
    """

    private let fallbackChapters: [NovelChapterItem] = [
        NovelChapterItem(id: "ch001", title: "Ch.001 星辉觉醒", hasDivergence: true, humanLocked: true),
        NovelChapterItem(id: "ch002", title: "Ch.002 墨影回廊", hasDivergence: false, humanLocked: false),
        NovelChapterItem(id: "ch003", title: "Ch.003 双生分镜", hasDivergence: false, humanLocked: false),
    ]

    public init(
        layout: WorkspaceLayoutHintKind,
        hintModeActive: Bool,
        hingeAvoidanceWidthPt: CGFloat = 0,
        activeProjectDir: String = SuiteSharedWorkspace.defaultProjectDir
    ) {
        self.layout = layout
        self.hintModeActive = hintModeActive
        self.hingeAvoidanceWidthPt = hingeAvoidanceWidthPt
        self.activeProjectDir = activeProjectDir
    }

    public var body: some View {
        HStack(spacing: 0) {
            if !zenMode {
                novelIconRail
                Divider()
            }

            if !zenMode && showOutline && layout != .singlePaneCompact {
                outlineSidebar
                    .frame(width: 236)
                Divider()
            }

            editorCanvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !zenMode && showAiRefDrawer && layout != .singlePaneCompact {
                Divider()
                aiReferenceDrawer
                    .frame(width: 268)
            }
        }
        .background(theme.background)
        .task(id: activeProjectDir) {
            // S3 v0.3.2 Live <300ms SLA disk revision watcher (250ms poll interval; zero cursor disruption)
            await runHotReloadWatcher()
        }
    }

    @MainActor
    private func runHotReloadWatcher() async {
        syncStoryBibleFromDisk(force: true)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { break }
            syncStoryBibleFromDisk(force: false)
        }
    }

    @MainActor
    private func syncStoryBibleFromDisk(force: Bool) {
        #if canImport(MangaCoreFFI)
        let t0 = Date()
        let currentHash = MangaStoryBible.revisionHash(projectDir: activeProjectDir)
        if force || currentHash != observedRevisionHash {
            observedRevisionHash = currentHash
            liveBibleCharacters = MangaStoryBible.readCharacters(projectDir: activeProjectDir)
            liveTocEntries = MangaStoryBible.readTocEntries(projectDir: activeProjectDir)
            lastHotReloadMs = Date().timeIntervalSince(t0) * 1000.0
        }
        #endif
    }

    // MARK: - 56px Calm Sage Icon Rail

    private var novelIconRail: some View {
        VStack(spacing: 8) {
            ForEach(railItems) { item in
                RailIconHintButton(
                    spec: item,
                    isSelected: isRailSelected(item.id),
                    accent: SuiteColorTokens.novelAccent,
                    isDarkChrome: theme.isDark,
                    hintModeActive: hintModeActive
                ) {
                    handleRailTap(item.id)
                }
            }
            Spacer()
            Text("S3")
                .font(.caption2.monospaced().bold())
                .foregroundStyle(SuiteColorTokens.novelAccent)
                .padding(.bottom, 8)
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(theme.chromeBackground)
    }

    private var railItems: [ToolHintSpec] {
        [
            ToolHintSpec(
                id: "prose",
                glyph: .novelProse,
                title: "Human Canon Prose",
                roleBadge: "S3 RW",
                summary: "Write decoupled light novel chapters saved atomically to novel/prose/<lang>.md.",
                shortcut: "⌘S",
                ownershipCue: "RAM < 120 MB · Zero GPU"
            ),
            ToolHintSpec(
                id: "outline",
                glyph: .novelOutline,
                title: "Chapter Outline (RO)",
                roleBadge: "Shared .prj",
                summary: "Toggle live read-only CPFF chapter tree & Story Bible synced from S1 (< 300ms).",
                shortcut: "⌘\\",
                ownershipCue: "RO Hot-Reload from S1"
            ),
            ToolHintSpec(
                id: "theme",
                glyph: .novelTheme,
                title: "Paper Theme Cycle",
                roleBadge: theme.rawValue,
                summary: "Cycle Warm Paper (#FAF8F4), Sepia (#F3EDE0), and Night Ink (#181A1F).",
                shortcut: "⌥⌘T",
                ownershipCue: "Eye-Friendly Typography"
            ),
            ToolHintSpec(
                id: "zen",
                glyph: .novelZen,
                title: "Zen Focus Mode",
                roleBadge: "Distraction-Free",
                summary: "Hide chrome and sidebars for pure distraction-free prose drafting.",
                shortcut: "⇧⌘Z",
                ownershipCue: "Tap pill to exit Zen"
            ),
            ToolHintSpec(
                id: "aiRef",
                glyph: .novelAiRef,
                title: "AI Reference Drawer",
                roleBadge: "Read-Only",
                summary: "Inspect local Gemma 4 drafts from ai_assist/manga_to_novel/ without auto-overwrite.",
                shortcut: "⌥⌘A",
                ownershipCue: "ai_reference_only Sandbox"
            ),
            ToolHintSpec(
                id: "lock",
                glyph: .novelLock,
                title: "Human Final Lock",
                roleBadge: "Protected",
                summary: "Locked prose files reject automated writes in Rust novel.rs.",
                shortcut: "⌥⌘L",
                ownershipCue: "locked=\"true\" Guard"
            ),
        ]
    }

    // MARK: - Outline Sidebar & Editor Canvas

    private var displayedChapters: [NovelChapterItem] {
        if liveTocEntries.isEmpty {
            return fallbackChapters
        }
        return liveTocEntries.map { entry in
            let title = entry.titleZh.isEmpty ? entry.titleEn : entry.titleZh
            return NovelChapterItem(
                id: entry.id,
                title: "Ch.\(String(format: "%03d", entry.number)) \(title)",
                hasDivergence: entry.id == "ch001",
                humanLocked: entry.id == "ch001"
            )
        }
    }

    private var outlineSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("CPFF Chapters (RO)")
                    .font(.caption.bold())
                    .foregroundStyle(theme.textColor.opacity(0.75))

                ForEach(displayedChapters) { ch in
                    let active = ch.id == selectedChapterId
                    Button {
                        selectedChapterId = ch.id
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ch.title)
                                    .font(.caption.weight(active ? .bold : .regular))
                                    .foregroundStyle(theme.textColor)
                                    .lineLimit(1)
                                Spacer()
                                if ch.humanLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(SuiteColorTokens.novelAccent)
                                }
                            }
                            if ch.hasDivergence {
                                Text("DivergenceNote · Manga ↔ Novel")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(SuiteColorTokens.divergenceAmber.opacity(0.16))
                                    .foregroundStyle(SuiteColorTokens.divergenceAmber)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(active ? SuiteColorTokens.novelAccent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Story Bible (RO)")
                            .font(.caption.bold())
                            .foregroundStyle(theme.textColor.opacity(0.75))
                        Spacer()
                        Text(String(format: "%.1fms", max(0.1, lastHotReloadMs)))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SuiteColorTokens.novelAccent.opacity(0.15))
                            .foregroundStyle(SuiteColorTokens.novelAccent)
                            .clipShape(Capsule())
                    }

                    if liveBibleCharacters.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(SuiteColorTokens.hubAccent).frame(width: 8, height: 8)
                            Text("林晓 · Lin Xiao (Protagonist)")
                                .font(.caption2)
                                .foregroundStyle(theme.textColor.opacity(0.85))
                        }
                    } else {
                        ForEach(liveBibleCharacters) { character in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(character.role == "rival" ? SuiteColorTokens.mangaAccent : SuiteColorTokens.hubAccent)
                                    .frame(width: 8, height: 8)
                                Text("\(character.nameZh) · \(character.nameEn) (\(character.role))")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textColor.opacity(0.88))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Text("Hash #\(String(observedRevisionHash, radix: 16).prefix(6).uppercased()) · 250ms watch")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textColor.opacity(0.55))
                }

                Divider()

                Text("RAM Budget: \(novelRamBudgetMb) MB · GPU: Off")
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.textColor.opacity(0.6))
            }
            .padding(12)
        }
        .background(theme.chromeBackground)
    }

    private var editorCanvas: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if zenMode {
                    Button {
                        zenMode = false
                    } label: {
                        Label("Exit Zen", systemImage: "arrow.down.right.and.arrow.up.left")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(SuiteColorTokens.novelAccent.opacity(0.18))
                            .foregroundStyle(SuiteColorTokens.novelAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Picker("Theme", selection: $theme) {
                        ForEach(PaperThemeKind.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }

                Spacer()

                Button {
                    performAtomicDraftSave()
                } label: {
                    Label("Atomic Save", systemImage: "checkmark.circle")
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(SuiteColorTokens.novelAccent.opacity(0.16))
                        .foregroundStyle(SuiteColorTokens.novelAccent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Text("Rust Units: \(rustUnitCount) · ~\(estimatedMinutes) min read")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(SuiteColorTokens.novelAccent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            TextEditor(text: $proseText)
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(theme.textColor)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, zenMode ? 56 : 24)
                .padding(.vertical, 10)
                .frame(maxWidth: 760, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performAtomicDraftSave() {
        #if canImport(MangaCoreFFI)
        try? FileManager.default.createDirectory(atPath: activeProjectDir, withIntermediateDirectories: true)
        _ = MangaNovelMetrics.saveProseAtomic(
            projectDir: activeProjectDir,
            relPath: "chapters/\(selectedChapterId)/novel/prose/zh-Hans.md",
            markdown: proseText,
            isLocked: false,
            explicitHumanEdit: true
        )
        #endif
    }

    private var aiReferenceDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            AiSandboxReadOnlyBanner(
                title: "AI Reference Drawer",
                subtitle: "Strict read-only view of ai_assist/manga_to_novel/."
            )

            ScrollView {
                Text(aiReferenceDraft)
                    .font(.caption)
                    .foregroundStyle(theme.textColor.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                proseText.append("\n\n" + aiReferenceDraft)
            } label: {
                Label("Append Snippet Manually", systemImage: "doc.on.clipboard")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(SuiteColorTokens.aiSandboxViolet)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(theme.chromeBackground)
    }

    // MARK: - Rust FFI Metrics & Helpers

    private var rustUnitCount: Int {
        #if canImport(MangaCoreFFI)
        return MangaNovelMetrics.countUnits(in: proseText)
        #else
        return proseText.split(whereSeparator: { $0.isWhitespace }).count
        #endif
    }

    private var estimatedMinutes: Int {
        max(1, (rustUnitCount + 349) / 350)
    }

    private var novelRamBudgetMb: UInt32 {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.ramBudgetMb(for: .novel)
        #else
        return 120
        #endif
    }

    private func isRailSelected(_ id: String) -> Bool {
        switch id {
        case "prose": return true
        case "outline": return showOutline
        case "zen": return zenMode
        case "aiRef": return showAiRefDrawer
        default: return false
        }
    }

    private func handleRailTap(_ id: String) {
        switch id {
        case "outline": showOutline.toggle()
        case "theme":
            let all = PaperThemeKind.allCases
            if let idx = all.firstIndex(of: theme) {
                theme = all[(idx + 1) % all.count]
            }
        case "zen": zenMode.toggle()
        case "aiRef": showAiRefDrawer.toggle()
        default: break
        }
    }
}
#endif
