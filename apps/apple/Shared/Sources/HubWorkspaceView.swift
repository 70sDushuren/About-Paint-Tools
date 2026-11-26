import Foundation

#if canImport(SwiftUI)
import SwiftUI

public enum HubSectionKind: String, CaseIterable, Sendable, Identifiable {
    case overview
    case newProject
    case dualBoard
    case ingest
    case localeAudit
    case publish

    public var id: String { rawValue }
}

/// `S1 v0.2.2` — `创想空间 / NoemaDock` (Working Codename) native shell:
/// 56px Indigo icon rail + 4-element Hint Popovers + live CPFF v1.0 `.prj` bootstrap via Rust FFI.
public struct HubWorkspaceView: View {
    public let layout: WorkspaceLayoutHintKind
    public let hintModeActive: Bool
    public let onOpenTool: (SuiteAppKind) -> Void

    @State private var selectedSection: HubSectionKind = .overview
    @State private var projectFolderName: String = "StarlightChronicle"
    @State private var projectAuthor: String = "Studio Creator"
    @State private var bootstrapStatus: String = "Ready to generate canonical CPFF v1.0 .prj workspace."
    @State private var lastCreatedPath: String?
    @State private var lastCreatedSucceeded: Bool?

    public init(
        layout: WorkspaceLayoutHintKind,
        hintModeActive: Bool,
        onOpenTool: @escaping (SuiteAppKind) -> Void
    ) {
        self.layout = layout
        self.hintModeActive = hintModeActive
        self.onOpenTool = onOpenTool
    }

    public var body: some View {
        HStack(spacing: 0) {
            iconRail
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBanner
                    switch selectedSection {
                    case .overview:
                        overviewCards
                    case .newProject:
                        newProjectBootstrapCard
                    case .dualBoard:
                        dualEngineBoardCard
                    case .ingest, .localeAudit, .publish:
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
                ownershipCue: "S1 RW: *.prj, outline/*"
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

    private var overviewCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            let paths = [
                "SampleManga.prj",
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
                    Text("Manga: B4 600DPI + Webtoon · 24p")
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
                    Text("Prose: zh-Hans / en · Human Locked")
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

    private func milestonePreviewCard(for section: HubSectionKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scheduled Module: \(section.rawValue)")
                .font(.subheadline.bold())
            Text("This S1 icon-rail workspace slot is wired and reserved for its upcoming SemVer v0.x patch milestone.")
                .font(.caption)
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
        return path.hasSuffix(".prj") || path.hasPrefix("outline/")
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
}
#endif
