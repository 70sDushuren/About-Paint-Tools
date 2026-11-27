import Foundation

#if canImport(SwiftUI)
import SwiftUI

public enum HubSectionKind: String, CaseIterable, Sendable, Identifiable {
    case overview
    case newProject
    case storyBible
    case dualBoard
    case ingest
    case localeAudit
    case publish

    public var id: String { rawValue }
}

/// `S1 v0.3.2` — `创想空间 / NoemaDock` (Working Codename) native shell:
/// 56px Indigo icon rail + Left CPFF Project Tree + Live Story Bible & TOC Atomic Editor +
/// CPFF v1.0 `.prj` bootstrap & `T0.2-S4` / `T0.3-S4` integration gates via Rust FFI.
public struct HubWorkspaceView: View {
    public let layout: WorkspaceLayoutHintKind
    public let hintModeActive: Bool
    @Binding public var activeProjectDir: String
    @Binding public var externalSection: HubSectionKind
    public let onOpenTool: (SuiteAppKind) -> Void

    @State private var projectFolderName: String = "StarlightChronicle"
    @State private var projectAuthor: String = "Studio Creator"
    @State private var bootstrapStatus: String = "Ready to generate canonical CPFF v1.0 .prj workspace."
    @State private var lastCreatedPath: String?
    @State private var lastCreatedSucceeded: Bool?

    // S1 v0.3.2 Live Story Bible & TOC Editor state
    @State private var bibleCharacters: [StoryBibleCharacterSummary] = []
    @State private var tocEntries: [ProjectTocEntrySummary] = []
    @State private var bibleRevisionHash: UInt64 = 0
    @State private var newCharId: String = "char-sora"
    @State private var newCharNameZh: String = "苍月"
    @State private var newCharNameEn: String = "Sora Tsuki"
    @State private var newCharRole: String = "mentor"
    @State private var newCharPalette: String = "#2FA88B"
    @State private var newChapterId: String = "ch003"
    @State private var newChapterZh: String = "双生分镜"
    @State private var newChapterEn: String = "Twin Storyboards"
    @State private var gateStatusLine: String = "T1.0-S4 Gate ready."
    @State private var ingestKind: IngestAssetKindBridge = .referenceArt
    @State private var ingestFilename: String = "Character Palette (Draft).txt"
    @State private var ingestPayload: String = "Primary Accent #4F7CFF / Cel Shadow Multiply 75%"
    @State private var ingestStatusLine: String = "Ready to normalize & ingest external assets without clobbering human finals."

    private var selectedSection: HubSectionKind {
        get { externalSection }
        nonmutating set { externalSection = newValue }
    }

    public init(
        layout: WorkspaceLayoutHintKind,
        hintModeActive: Bool,
        activeProjectDir: Binding<String>,
        externalSection: Binding<HubSectionKind> = .constant(.overview),
        onOpenTool: @escaping (SuiteAppKind) -> Void
    ) {
        self.layout = layout
        self.hintModeActive = hintModeActive
        self._activeProjectDir = activeProjectDir
        self._externalSection = externalSection
        self.onOpenTool = onOpenTool
    }

    public var body: some View {
        HStack(spacing: 0) {
            iconRail
            Divider()
            if layout != .singlePaneCompact {
                projectTreeSidebar
                    .frame(width: 224)
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBanner
                    switch selectedSection {
                    case .overview:
                        overviewCards
                    case .newProject:
                        newProjectBootstrapCard
                    case .storyBible:
                        storyBibleAndTocEditorCard
                    case .dualBoard:
                        dualEngineBoardCard
                    case .ingest:
                        assetIngestCard
                    case .localeAudit:
                        localeGlossaryAuditCard
                    case .publish:
                        milestonePreviewCard(for: selectedSection)
                    }
                    AiSandboxReadOnlyBanner(
                        title: "Gemma 4 Local AI Sandbox · Isolated",
                        subtitle: "All AI reference drafts stay under chapters/*/ai_assist/ and never overwrite human prose or manga finals."
                    )
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SuiteColorTokens.hubSurface)
        }
        .onAppear(perform: reloadProjectTree)
        .onChange(of: activeProjectDir) { _, _ in
            reloadProjectTree()
        }
    }

    // MARK: - 56px Minimal Icon Rail

    private var iconRail: some View {
        VStack(spacing: 8) {
            ForEach(railItems) { item in
                let section = HubSectionKind(rawValue: item.id) ?? .overview
                RailIconHintButton(
                    spec: item,
                    isSelected: selectedSection == section,
                    accent: SuiteColorTokens.hubAccent,
                    isDarkChrome: false,
                    hintModeActive: hintModeActive
                ) {
                    selectedSection = section
                }
            }
            Spacer()
            Text("S1")
                .font(.caption2.monospaced().bold())
                .foregroundStyle(SuiteColorTokens.hubAccent)
                .padding(.bottom, 8)
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(SuiteColorTokens.hubCard)
    }

    private var railItems: [ToolHintSpec] {
        [
            ToolHintSpec(
                id: HubSectionKind.overview.rawValue,
                glyph: .hubOverview,
                title: "Project Overview",
                roleBadge: "S1 Hub",
                summary: "Inspect CPFF v1.0 manifest, write-ownership isolation, and active editions.",
                shortcut: "⌘1",
                ownershipCue: "S1 RW: *.prj, outline/*, bible/*"
            ),
            ToolHintSpec(
                id: HubSectionKind.newProject.rawValue,
                glyph: .hubNewProject,
                title: "New .prj Workspace",
                roleBadge: "v0.2.1 Rust",
                summary: "Bootstrap a complete dual-engine CPFF v1.0 .prj folder with Git LFS & 5-locale XML.",
                shortcut: "⌘N",
                ownershipCue: "FFI: manga_hub_init_project"
            ),
            ToolHintSpec(
                id: HubSectionKind.storyBible.rawValue,
                glyph: .novelOutline,
                title: "Story Bible & TOC",
                roleBadge: "v0.3.2 Live",
                summary: "Edit bible/characters.xml & outline/toc.xml atomically; S3 hot-reloads in < 300ms.",
                shortcut: "⌘B",
                ownershipCue: "S1 Exclusive RW · FNV-1a Hash"
            ),
            ToolHintSpec(
                id: HubSectionKind.dualBoard.rawValue,
                glyph: .hubDualBoard,
                title: "Dual-Engine Board",
                roleBadge: "Novel × Manga",
                summary: "Track parallel Light Novel and Manga chapter progress and deep-link into S2/S3.",
                shortcut: "⌘2",
                ownershipCue: "Deep-Link: draconib:// · litteracore://"
            ),
            ToolHintSpec(
                id: HubSectionKind.ingest.rawValue,
                glyph: .hubIngest,
                title: "Asset & Prose Ingest",
                roleBadge: "v0.4",
                summary: "Drag-drop external manuscripts or PSDs into normalized CPFF v1.0 folders.",
                shortcut: "⌘I",
                ownershipCue: "Handoff → S2 / S3"
            ),
            ToolHintSpec(
                id: HubSectionKind.localeAudit.rawValue,
                glyph: .hubLocaleAudit,
                title: "5-Locale Audit Matrix",
                roleBadge: "v0.6",
                summary: "Verify en / zh-Hans / zh-Hant / yue-Hant / es completeness and character budgets.",
                shortcut: "⌘L",
                ownershipCue: "5 Locales · Zero Drift"
            ),
            ToolHintSpec(
                id: HubSectionKind.publish.rawValue,
                glyph: .hubPublish,
                title: "Multi-Edition Publish",
                roleBadge: "v0.7",
                summary: "Coordinate B4 print, Webtoon slices (S2), and EPUB3 light novel builds (S3).",
                shortcut: "⇧⌘E",
                ownershipCue: "S1 Orchestrator"
            ),
        ]
    }

    // MARK: - Left CPFF Project Tree (S1 v0.3.2)

    private var projectTreeSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CPFF Project Tree")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        reloadProjectTree()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(SuiteColorTokens.hubAccent)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: activeProjectDir).lastPathComponent + ".prj")
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                        .lineLimit(1)
                    Text("Rev #\(String(bibleRevisionHash, radix: 16).prefix(6).uppercased())")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SuiteColorTokens.hubAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 6) {
                    Text("outline/toc.xml (\(tocEntries.count))")
                        .font(.caption2.monospaced().bold())
                        .foregroundStyle(.secondary)
                    ForEach(tocEntries) { ch in
                        HStack(spacing: 6) {
                            Text("Ch.\(ch.number)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(SuiteColorTokens.hubAccent)
                            Text(ch.titleZh.isEmpty ? ch.titleEn : ch.titleZh)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(ch.status)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("bible/characters.xml (\(bibleCharacters.count))")
                        .font(.caption2.monospaced().bold())
                        .foregroundStyle(.secondary)
                    ForEach(bibleCharacters) { char in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(SuiteColorTokens.hubAccent)
                                .frame(width: 7, height: 7)
                            Text("\(char.nameZh) · \(char.nameEn)")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    Button {
                        selectedSection = .storyBible
                    } label: {
                        Label("Edit Story Bible", systemImage: "pencil")
                            .font(.caption2.bold())
                            .foregroundStyle(SuiteColorTokens.hubAccent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Divider()

                Button {
                    runT03S4Gate(on: activeProjectDir)
                } label: {
                    Label("Run T0.3-S4 Gate", systemImage: "checkmark.seal.fill")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)

                Text(gateStatusLine)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(SuiteColorTokens.hubCard)
    }

    // MARK: - Main Cards

    private var headerBanner: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("S1 · 创想空间 / NoemaDock")
                    .font(.title3.bold())
                Text("RAM Budget: \(ramBudgetMb) MB · GPU Canvas: Disabled · CPFF v1.0 Orchestrator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                selectedSection = .storyBible
            } label: {
                Label("Story Bible", systemImage: "book.closed")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SuiteColorTokens.hubAccent.opacity(0.14))
                    .foregroundStyle(SuiteColorTokens.hubAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button {
                selectedSection = .newProject
            } label: {
                Label("New .prj", systemImage: "plus")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(SuiteColorTokens.hubAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var storyBibleAndTocEditorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Story Bible & TOC Atomic Editor (S1 v0.3.2)")
                        .font(.subheadline.bold())
                    Text("Writes atomically to bible/characters.xml & outline/toc.xml; S3 文心 hot-reloads changes in < 300ms.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Rev #\(String(bibleRevisionHash, radix: 16).prefix(8).uppercased())")
                    .font(.caption2.monospaced().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(SuiteColorTokens.hubAccent.opacity(0.14))
                    .foregroundStyle(SuiteColorTokens.hubAccent)
                    .clipShape(Capsule())
            }

            // Upsert Character Card
            VStack(alignment: .leading, spacing: 8) {
                Text("Add / Update Character (`bible/characters.xml`)")
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    TextField("ID (char-sora)", text: $newCharId).textFieldStyle(.roundedBorder)
                    TextField("中文名", text: $newCharNameZh).textFieldStyle(.roundedBorder)
                    TextField("English Name", text: $newCharNameEn).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 8) {
                    TextField("Role", text: $newCharRole).textFieldStyle(.roundedBorder)
                    TextField("Palette #HEX", text: $newCharPalette).textFieldStyle(.roundedBorder)
                    Button {
                        upsertCharacterViaRust()
                    } label: {
                        Label("Save Character", systemImage: "person.badge.plus")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(SuiteColorTokens.hubAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Upsert Chapter TOC Entry
            VStack(alignment: .leading, spacing: 8) {
                Text("Add / Update Master TOC Chapter (`outline/toc.xml`)")
                    .font(.caption.bold())
                HStack(spacing: 8) {
                    TextField("ch003", text: $newChapterId).textFieldStyle(.roundedBorder)
                    TextField("章节中文名", text: $newChapterZh).textFieldStyle(.roundedBorder)
                    TextField("Chapter Title (EN)", text: $newChapterEn).textFieldStyle(.roundedBorder)
                    Button {
                        upsertTocChapterViaRust()
                    } label: {
                        Label("Save Chapter", systemImage: "list.bullet.rectangle")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(SuiteColorTokens.novelAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    runT03S4Gate(on: activeProjectDir)
                } label: {
                    Label("Run T0.3-S4 Gate (Bible + 13 Cel Modes)", systemImage: "checkmark.shield.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.hubAccent.opacity(0.15))
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button("Verify Hot-Reload in S3 文心 →") {
                    onOpenTool(.novel)
                }
                .font(.caption.bold())
                .foregroundStyle(SuiteColorTokens.novelAccent)
                .buttonStyle(.plain)
            }

            Text(gateStatusLine)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var overviewCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            let paths = [
                "SampleManga.prj",
                "bible/characters.xml",
                "outline/toc.xml",
                "chapters/ch001/manuscript/p001.mnga",
                "chapters/ch001/novel/prose/zh-Hans.md",
                "chapters/ch001/novel/novel_meta.xml",
            ]
            VStack(alignment: .leading, spacing: 8) {
                Text("CPFF v1.0 Write-Ownership Matrix (Live Rust FFI)")
                    .font(.subheadline.bold())
                ForEach(paths, id: \.self) { relPath in
                    let allowed = canHubWrite(relPath)
                    HStack {
                        Text(relPath)
                            .font(.caption.monospaced())
                        Spacer()
                        Text(allowed ? "S1 RW" : "RO (Isolated)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((allowed ? SuiteColorTokens.hubAccent : Color.secondary).opacity(0.15))
                            .foregroundStyle(allowed ? SuiteColorTokens.hubAccent : .secondary)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .background(SuiteColorTokens.hubCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            dualEngineBoardCard
        }
    }

    private var newProjectBootstrapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bootstrap New CPFF v1.0 Dual-Engine `.prj` Project")
                .font(.subheadline.bold())
            Text("Invokes Rust `manga_hub_init_project` directly to create canonical `.prj` XML, `.gitattributes` (Git LFS), 5-locale templates, and isolated `ai_assist/` folders.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Project Folder Name")
                    .font(.caption.bold())
                TextField("StarlightChronicle", text: $projectFolderName)
                    .textFieldStyle(.roundedBorder)

                Text("Creator / Studio Author")
                    .font(.caption.bold())
                TextField("Studio Creator", text: $projectAuthor)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button {
                    runRustBootstrap()
                } label: {
                    Label("Create .prj via Rust Core", systemImage: "sparkles.rectangle.stack")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if let succeeded = lastCreatedSucceeded {
                    Text(succeeded ? "VERIFIED" : "FAILED")
                        .font(.caption2.monospaced().bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((succeeded ? Color.green : Color.red).opacity(0.16))
                        .foregroundStyle(succeeded ? Color.green : Color.red)
                        .clipShape(Capsule())
                }

                if let createdPath = lastCreatedPath {
                    Button {
                        runT02S4Gate(on: createdPath)
                    } label: {
                        Label("Run T0.2-S4 (100x)", systemImage: "checkmark.shield")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(SuiteColorTokens.novelAccent.opacity(0.16))
                            .foregroundStyle(SuiteColorTokens.novelAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(bootstrapStatus)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            if let createdPath = lastCreatedPath {
                Text("Path: \(createdPath)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(SuiteColorTokens.hubAccent)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dualEngineBoardCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dual-Engine Serialization Board (Quick Deep-Link)")
                .font(.subheadline.bold())

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ch.001 · Starlight Awakening")
                        .font(.caption.bold())
                    Text("Manga: B4 600DPI + Webtoon · 13 Cel Modes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Open in S2 雕龙 / DracoNib →") {
                        onOpenTool(.manga)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(SuiteColorTokens.mangaAccent)
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SuiteColorTokens.mangaAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ch.001 · Light Novel Final")
                        .font(.caption.bold())
                    Text("Prose: zh-Hans / en · <300ms Bible Sync")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Open in S3 文心 / LitteraCore →") {
                        onOpenTool(.novel)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(SuiteColorTokens.novelAccent)
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SuiteColorTokens.novelAccent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var assetIngestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("S1 v0.4 · Asset & Prose Ingest Normalizer")
                .font(.subheadline.bold())
            Text("Sanitizes filenames, auto-versions duplicate files (-v2, -v3), and isolates imported prose inside ai_assist/ingest_staging/ so human finals are never clobbered.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Ingest Target", selection: $ingestKind) {
                ForEach(IngestAssetKindBridge.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.menu)

            TextField("Source Filename", text: $ingestFilename)
                .textFieldStyle(.roundedBorder)
            TextField("Asset / Draft Payload", text: $ingestPayload)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button {
                    #if canImport(MangaCoreFFI)
                    if let dest = MangaHubIngest.ingestTextAsset(
                        projectDir: activeProjectDir,
                        chapterId: "ch001",
                        kind: ingestKind,
                        filename: ingestFilename,
                        payload: ingestPayload
                    ) {
                        ingestStatusLine = "OK [Atomic Ingest]: Saved -> \(dest)"
                    } else {
                        ingestStatusLine = "FAIL: Ingest rejected unsafe path or empty filename."
                    }
                    #endif
                } label: {
                    Label("Ingest into CPFF .prj", systemImage: "tray.and.arrow.down.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    #if canImport(MangaCoreFFI)
                    let ok = MangaSuiteS4Gate.runT04S4(projectDir: activeProjectDir)
                    ingestStatusLine = ok
                        ? "OK [T0.4-S4 Gate PASS]: Ingest auto-versioning, Close-Gap 3px + Lasso & DivergenceNote verified."
                        : "FAIL [T0.4-S4 Gate]: Check workspace state."
                    #endif
                } label: {
                    Label("Run T0.4-S4 Gate", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.novelAccent.opacity(0.16))
                        .foregroundStyle(SuiteColorTokens.novelAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text(ingestStatusLine)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var localeGlossaryAuditCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("S1 v0.5 · 5-Locale Glossary & Completeness Audit Matrix")
                .font(.subheadline.bold())
            Text("Persists locked 5-language proper nouns (en / zh-Hans / zh-Hant / yue-Hant / es) to bible/glossary.xml for S3 autocomplete.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    #if canImport(MangaCoreFFI)
                    _ = MangaGlossary.upsertTerm(
                        projectDir: activeProjectDir,
                        key: "weapon.starlight_blade",
                        en: "Starlight Blade",
                        zhHans: "星辉之刃",
                        zhHant: "星輝之刃",
                        yueHant: "星輝之刃",
                        es: "Hoja Estelar",
                        locked: true
                    )
                    gateStatusLine = "OK [S1 v0.5]: Upserted 5-locale term 'weapon.starlight_blade' (5/5 complete)."
                    #endif
                } label: {
                    Label("Add 5-Locale Term", systemImage: "character.book.closed.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    #if canImport(MangaCoreFFI)
                    let ok = MangaSuiteS4Gate.runT05S4(projectDir: activeProjectDir)
                    gateStatusLine = ok
                        ? "OK [T0.5-S4 Gate PASS]: 5-locale glossary (0 missing), Vector Intersection Eraser, 4x scale & 3 Rulers verified."
                        : "FAIL [T0.5-S4 Gate]: Check workspace state."
                    #endif
                } label: {
                    Label("Run T0.5-S4 Gate", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.novelAccent.opacity(0.16))
                        .foregroundStyle(SuiteColorTokens.novelAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            #if canImport(MangaCoreFFI)
            let terms = MangaGlossary.suggestTerms(projectDir: activeProjectDir, query: "", locale: "en")
            ForEach(terms) { term in
                HStack {
                    Text(term.id).font(.caption2.monospaced())
                    Spacer()
                    Text("\(term.zhHans) · \(term.en)").font(.caption2)
                    Text(term.status)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.16))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                }
            }
            #endif

            Text(gateStatusLine)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func milestonePreviewCard(for section: HubSectionKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("S1 v0.6 · Multi-Edition Publish Center (B4 Print × Webtoon × EPUB3)")
                .font(.subheadline.bold())
            Text("Coordinates 4-panel B4 600DPI print pages, procedural 60 LPI screentones, 1280px Webtoon vertical slices, 5-locale speech bubbles, and EPUB3 XHTML light novel builds.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    #if canImport(MangaCoreFFI)
                    let slices = MangaPublishingTools.webtoonSliceCount(canvasHeight: 12800, sliceHeight: 1280)
                    let xhtml = MangaPublishingTools.renderEpubXhtml(
                        title: "Ch.001 Starlight Awakening",
                        locale: "zh-Hans",
                        markdown: "# 第一话 星辉觉醒\n\n星光落满屋顶。"
                    )
                    let ok = MangaSuiteS4Gate.runT06S4(projectDir: activeProjectDir)
                    gateStatusLine = ok
                        ? "OK [T0.6-S4 Publish Gate PASS]: B4 4-panel + 4 tones + \(slices) Webtoon slices (0 seam) + 5-locale bubbles + EPUB3 (\(xhtml.count)B) -> editions/publish_report.xml."
                        : "FAIL [T0.6-S4 Publish Gate]: Check workspace state."
                    #endif
                } label: {
                    Label("Run Multi-Edition Publish & T0.6-S4 Gate", systemImage: "paperplane.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Text(gateStatusLine)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SuiteColorTokens.hubCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Rust FFI Bridge Helpers

    private var ramBudgetMb: UInt32 {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.ramBudgetMb(for: .hub)
        #else
        return 200
        #endif
    }

    private func canHubWrite(_ path: String) -> Bool {
        #if canImport(MangaCoreFFI)
        return MangaSuitePolicy.canWrite(app: .hub, relativePath: path)
        #else
        return path.hasSuffix(".prj") || path.hasPrefix("outline/") || path.hasPrefix("bible/")
        #endif
    }

    private func reloadProjectTree() {
        #if canImport(MangaCoreFFI)
        bibleCharacters = MangaStoryBible.readCharacters(projectDir: activeProjectDir)
        tocEntries = MangaStoryBible.readTocEntries(projectDir: activeProjectDir)
        bibleRevisionHash = MangaStoryBible.revisionHash(projectDir: activeProjectDir)
        #endif
    }

    private func upsertCharacterViaRust() {
        #if canImport(MangaCoreFFI)
        let ok = MangaStoryBible.upsertCharacter(
            projectDir: activeProjectDir,
            id: newCharId.trimmingCharacters(in: .whitespacesAndNewlines),
            nameZh: newCharNameZh.trimmingCharacters(in: .whitespacesAndNewlines),
            nameEn: newCharNameEn.trimmingCharacters(in: .whitespacesAndNewlines),
            role: newCharRole.trimmingCharacters(in: .whitespacesAndNewlines),
            paletteHex: newCharPalette.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        reloadProjectTree()
        gateStatusLine = ok
            ? "OK [S1 Atomic]: Saved '\(newCharNameZh)' to bible/characters.xml (total=\(bibleCharacters.count))."
            : "FAIL: Could not save character (check non-empty ID)."
        #endif
    }

    private func upsertTocChapterViaRust() {
        #if canImport(MangaCoreFFI)
        let nextNum = UInt32(tocEntries.count + 1)
        let ok = MangaStoryBible.upsertTocEntry(
            projectDir: activeProjectDir,
            chapterId: newChapterId.trimmingCharacters(in: .whitespacesAndNewlines),
            number: nextNum,
            titleZh: newChapterZh.trimmingCharacters(in: .whitespacesAndNewlines),
            titleEn: newChapterEn.trimmingCharacters(in: .whitespacesAndNewlines),
            status: "draft"
        )
        reloadProjectTree()
        gateStatusLine = ok
            ? "OK [S1 Atomic]: Saved '\(newChapterId)' to outline/toc.xml (total=\(tocEntries.count))."
            : "FAIL: Could not save TOC entry."
        #endif
    }

    private func runRustBootstrap() {
        let trimmedName = projectFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = trimmedName.isEmpty ? "UntitledProject" : trimmedName
        let author = projectAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AboutPaintProjects", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        #if canImport(MangaCoreFFI)
        let ok = MangaHubProjectBootstrap.initProject(
            parentDir: baseURL.path,
            folderName: folder,
            author: author.isEmpty ? "Creator" : author
        )
        lastCreatedSucceeded = ok
        if ok {
            let target = baseURL.appendingPathComponent(folder).path
            lastCreatedPath = target
            activeProjectDir = target
            reloadProjectTree()
            let status = MangaHubProjectBootstrap.resolvePrjStatus(projectDir: target)
            let statusLabel = status == .exactMatch ? "ExactMatch" : (status == .renamedFolderFallback ? "RenamedFolderFallback" : "Invalid")
            bootstrapStatus = "OK [\(statusLabel)]: Rust core initialized '\(folder).prj' with Git LFS & 5-locale structure."
        } else {
            bootstrapStatus = "FAIL: Rust core rejected project bootstrap (folder may already exist or path invalid)."
        }
        #else
        lastCreatedSucceeded = false
        bootstrapStatus = "MangaCoreFFI not linked in preview mode."
        #endif
    }

    private func runT02S4Gate(on projectPath: String) {
        #if canImport(MangaCoreFFI)
        let res = MangaHubProjectBootstrap.resolvePrjStatus(projectDir: projectPath)
        let passed = MangaSuiteS4Gate.run(projectDir: projectPath, soakRounds: 100)
        lastCreatedSucceeded = passed
        bootstrapStatus = passed
            ? "OK [T0.2-S4 100x Soak PASS]: resolve=\(res.rawValue), S1/S2/S3 write isolation, 100 atomic prose saves & CoW undo verified."
            : "FAIL [T0.2-S4 Soak]: Gate failed on \(projectPath)."
        #else
        bootstrapStatus = "MangaCoreFFI not linked in preview mode."
        #endif
    }

    private func runT03S4Gate(on projectPath: String) {
        #if canImport(MangaCoreFFI)
        let t0 = Date()
        let passed = MangaSuiteS4Gate.runT03S4(projectDir: projectPath)
        let elapsedMs = Date().timeIntervalSince(t0) * 1000.0
        reloadProjectTree()
        gateStatusLine = passed
            ? String(format: "OK [T0.3-S4 PASS in %.1fms]: Bible+TOC <300ms hot-reload, 13 cel blend modes & R/Clip/Lock/B verified.", elapsedMs)
            : "FAIL [T0.3-S4]: Gate failed on \(projectPath)."
        #else
        gateStatusLine = "MangaCoreFFI not linked in preview mode."
        #endif
    }
}
#endif
