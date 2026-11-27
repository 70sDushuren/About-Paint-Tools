import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// `v1.0.0-rc2` — Full context-aware macOS / iPadOS Menu Bar synchronized 1:1 with
/// `StudioWorkspaceController` (active Tri-App tool `S1`/`S2`/`S3`, active drawing tool,
/// layer state, undo/redo availability, and 5-language live switching).
@MainActor
public struct StudioMenuCommands: Commands {
    @ObservedObject public var controller: StudioWorkspaceController

    public init(controller: StudioWorkspaceController) {
        self.controller = controller
    }

    public var body: some Commands {
        // MARK: - File Menu (Project Lifecycle & Exports)
        CommandGroup(replacing: .newItem) {
            Button("New Creative Project (.prj)…") {
                controller.switchSuiteApp(.hub)
                controller.hubSection = .newProject
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open Project Folder (.prj)…") {
                controller.presentOpenProjectDialog()
            }
            .keyboardShortcut("o", modifiers: .command)

            if !controller.recentProjectDirs.isEmpty {
                Menu("Open Recent Project") {
                    ForEach(controller.recentProjectDirs, id: \.self) { dir in
                        Button(URL(fileURLWithPath: dir).lastPathComponent) {
                            controller.openProjectDirectory(dir)
                        }
                    }
                }
            }

            Divider()

            Button("Save All Work Now") {
                controller.flushAllSync()
            }
            .keyboardShortcut("s", modifiers: .command)

            Divider()

            Button("Export Layered PSD (8BPS)…") {
                controller.dispatchCanvasCommand(.exportPsd(nil))
            }
            .keyboardShortcut("e", modifiers: [.shift, .command])
            .disabled(!controller.canExportArtwork)

            Button("Export Canvas PNG…") {
                controller.dispatchCanvasCommand(.exportPng(nil))
            }
            .disabled(!controller.canExportArtwork)

            Button("Export Novel EPUB3 XHTML…") {
                controller.presentExportEpubDialog()
            }
            .disabled(!controller.canExportEpub)
        }

        // MARK: - Edit Menu (Undo/Redo & Selection Operations)
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                controller.dispatchCanvasCommand(.undo)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!controller.canUndoInCurrentContext)

            Button("Redo") {
                controller.dispatchCanvasCommand(.redo)
            }
            .keyboardShortcut("z", modifiers: [.shift, .command])
            .disabled(!controller.canRedoInCurrentContext)

            Divider()

            Button("Select All") {
                controller.dispatchCanvasCommand(.selectAll)
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(!controller.isMangaContext)

            Button("Deselect") {
                controller.dispatchCanvasCommand(.deselect)
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(!controller.isMangaContext || !controller.s2HasActiveSelection)

            Button("Invert Selection") {
                controller.dispatchCanvasCommand(.invertSelection)
            }
            .keyboardShortcut("i", modifiers: [.shift, .command])
            .disabled(!controller.isMangaContext || !controller.s2HasActiveSelection)
        }

        // MARK: - Tool & Drawing Menu (Context-Sensitive for S2 Manga)
        CommandMenu("Drawing") {
            Section("Tools") {
                Button("Brush") { controller.selectTool(.brush) }
                    .keyboardShortcut("b", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Eraser") { controller.selectTool(.eraser) }
                    .keyboardShortcut("e", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Smudge") { controller.selectTool(.smudge) }
                    .keyboardShortcut("u", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Blur") { controller.selectTool(.blur) }
                    .disabled(!controller.isMangaContext)
                Button("Close-Gap Bucket Fill") { controller.selectTool(.bucket) }
                    .keyboardShortcut("g", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Lasso Selection") { controller.selectTool(.lasso) }
                    .keyboardShortcut("l", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Magic Wand") { controller.selectTool(.magicWand) }
                    .keyboardShortcut("w", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Eyedropper") { controller.selectTool(.eyedropper) }
                    .keyboardShortcut("i", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Transform") { controller.selectTool(.transform) }
                    .keyboardShortcut("t", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Panel Frame Divider") { controller.selectTool(.panelKnife) }
                    .keyboardShortcut("k", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Button("Text & Speech Bubble") { controller.selectTool(.textBubble) }
                    .keyboardShortcut("x", modifiers: [])
                    .disabled(!controller.isMangaContext)
            }

            Divider()

            Section("Active Tool Options") {
                Button("Increase Brush Size (+4px)") {
                    controller.adjustBrushSize(by: 4)
                }
                .keyboardShortcut("]", modifiers: [])
                .disabled(!controller.canAdjustBrushDynamics)

                Button("Decrease Brush Size (-4px)") {
                    controller.adjustBrushSize(by: -4)
                }
                .keyboardShortcut("[", modifiers: [])
                .disabled(!controller.canAdjustBrushDynamics)

                Toggle("Force Fade In / Out", isOn: $controller.s2ForceFade)
                    .disabled(!controller.canAdjustBrushDynamics)

                Menu("Bucket Close-Gap (\(controller.s2BucketCloseGapPx)px)") {
                    ForEach([0, 1, 2, 3, 5, 8], id: \.self) { px in
                        Button("\(px)px Gap Closure") {
                            controller.s2BucketCloseGapPx = px
                        }
                    }
                }
                .disabled(!controller.canAdjustBucketOptions)
            }

            Divider()

            Menu("Ruler Guide") {
                ForEach(RulerModeKind.allCases) { mode in
                    Button(mode == controller.s2RulerMode ? "✓ \(mode.displayName)" : mode.displayName) {
                        controller.s2RulerMode = mode
                    }
                }
            }
            .disabled(!controller.isMangaContext)

            Menu("Drawing Shape Assist") {
                ForEach(S2ShapeAssistKind.allCases) { shape in
                    Button(shape == controller.s2ShapeAssist ? "✓ \(shape.displayName)" : shape.displayName) {
                        controller.s2ShapeAssist = shape
                    }
                }
            }
            .disabled(!controller.isMangaContext)
        }

        // MARK: - Layer Menu (Context-Sensitive for S2 Manga)
        CommandMenu("Layer") {
            Button("New Raster Layer") {
                controller.dispatchCanvasCommand(.addLayer)
            }
            .keyboardShortcut("n", modifiers: [.shift, .command])
            .disabled(!controller.isMangaContext)

            Button("Duplicate Active Layer") {
                controller.dispatchCanvasCommand(.duplicateLayer)
            }
            .keyboardShortcut("j", modifiers: .command)
            .disabled(!controller.isMangaContext || controller.selectedCelLayer == nil)

            Button("Merge Down") {
                controller.dispatchCanvasCommand(.mergeLayerDown)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(!controller.canMergeSelectedLayerDown)

            Button("Delete Active Layer") {
                controller.dispatchCanvasCommand(.deleteLayer)
            }
            .disabled(!controller.canDeleteSelectedLayer)

            Button("Clear Active Layer") {
                controller.clearCurrentLayer()
            }
            .disabled(!controller.isMangaContext)

            Divider()

            Button("Flip Layer Horizontally") {
                controller.dispatchCanvasCommand(.flipLayerHorizontal)
            }
            .disabled(!controller.isMangaContext)

            Button("Flip Layer Vertically") {
                controller.dispatchCanvasCommand(.flipLayerVertical)
            }
            .disabled(!controller.isMangaContext)

            Divider()

            Button("Toggle Reference Layer (R)") {
                controller.toggleActiveLayerFlag(\.isReference)
            }
            .disabled(!controller.isMangaContext)

            Button("Toggle Clipping Mask (✂)") {
                controller.toggleActiveLayerFlag(\.clippingMask)
            }
            .disabled(!controller.isMangaContext)

            Button("Toggle Alpha Lock (🔒)") {
                controller.toggleActiveLayerFlag(\.alphaLock)
            }
            .disabled(!controller.isMangaContext)

            Button("Toggle Blue Sketch Tint (B)") {
                controller.toggleActiveLayerFlag(\.blueSketchTint)
            }
            .disabled(!controller.isMangaContext)

            Menu("Blend Mode") {
                ForEach(LayerBlendMode.allCases, id: \.rawValue) { mode in
                    Button(controller.selectedCelLayer?.blendMode == mode ? "✓ \(mode.displayName)" : mode.displayName) {
                        controller.setActiveLayerBlendMode(mode)
                    }
                }
            }
            .disabled(!controller.isMangaContext)
        }

        // MARK: - Filter (FX) Menu (Pulled forward into v1.0 for ibisPaint parity)
        CommandMenu("Filter") {
            ForEach(S2FilterActionKind.allCases) { fx in
                Button(fx.displayName) {
                    controller.dispatchCanvasCommand(.applyFilter(fx))
                }
                .disabled(!controller.canRunFilterOnSelectedLayer)
            }
        }

        // MARK: - Novel Menu (Context-Sensitive for S3 Novel)
        CommandMenu("Novel") {
            Button("Save Human Canon Prose") {
                _ = controller.saveNovelProseNow(explicitHumanEdit: true)
            }
            .disabled(!controller.isNovelContext)

            Toggle("Lock Human Final (locked=\"true\")", isOn: $controller.s3HumanLocked)
                .keyboardShortcut("l", modifiers: [.option, .command])
                .disabled(!controller.isNovelContext)

            Divider()

            Menu("Paper Theme") {
                ForEach(PaperThemeKind.allCases) { theme in
                    Button(controller.s3PaperTheme == theme ? "✓ \(theme.rawValue)" : theme.rawValue) {
                        controller.s3PaperTheme = theme
                    }
                }
            }
            .disabled(!controller.isNovelContext)

            Toggle("Zen Focus Mode", isOn: $controller.s3ZenMode)
                .keyboardShortcut("f", modifiers: [.shift, .command])
                .disabled(!controller.isNovelContext)

            Toggle("Outline & Story Bible Sidebar", isOn: $controller.s3ShowOutline)
                .keyboardShortcut("\\", modifiers: .command)
                .disabled(!controller.isNovelContext)

            Toggle("Read-Only AI Reference Drawer", isOn: $controller.s3ShowAiRefDrawer)
                .keyboardShortcut("a", modifiers: [.option, .command])
                .disabled(!controller.isNovelContext)
        }

        // MARK: - Workspace, View & Language Menu (Global + S1 Hub Jump)
        CommandMenu("Workspace") {
            Section("Tri-App Tools") {
                Button("S1 Hub · 创想空间 / NoemaDock") { controller.switchSuiteApp(.hub) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("S2 Manga · 雕龙 / DracoNib") { controller.switchSuiteApp(.manga) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("S3 Novel · 文心 / LitteraCore") { controller.switchSuiteApp(.novel) }
                    .keyboardShortcut("3", modifiers: .command)
            }

            Divider()

            Menu("S1 Hub Sections") {
                Button("Project Overview") { controller.switchSuiteApp(.hub); controller.hubSection = .overview }
                Button("Story Bible & TOC") { controller.switchSuiteApp(.hub); controller.hubSection = .storyBible }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Dual-Engine Board") { controller.switchSuiteApp(.hub); controller.hubSection = .dualBoard }
                Button("Asset & Prose Ingest") { controller.switchSuiteApp(.hub); controller.hubSection = .ingest }
                    .keyboardShortcut("i", modifiers: .command)
                Button("5-Locale Audit Matrix") { controller.switchSuiteApp(.hub); controller.hubSection = .localeAudit }
                Button("Multi-Edition Publish") { controller.switchSuiteApp(.hub); controller.hubSection = .publish }
            }

            Divider()

            Section("Canvas Viewport") {
                Button("Zoom In") { controller.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(!controller.isMangaContext)
                Button("Zoom Out") { controller.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(!controller.isMangaContext)
                Button("Reset Viewport (100%)") { controller.resetViewport() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(!controller.isMangaContext)
                Toggle("Horizontal Mirror Preview", isOn: $controller.s2MirrorHorizontal)
                    .keyboardShortcut("h", modifiers: [])
                    .disabled(!controller.isMangaContext)
                Toggle("Reference Window", isOn: $controller.s2ShowReferenceWindow)
                    .disabled(!controller.isMangaContext)
            }

            Divider()

            Toggle("Icon Hint Inspection Mode (?)", isOn: $controller.hintModeActive)

            Menu("App Language (5 Locales)") {
                ForEach(UiLocaleKind.allCases) { loc in
                    Button(loc == controller.activeLocale ? "✓ \(loc.nativeLabel)" : loc.nativeLabel) {
                        controller.activeLocale = loc
                    }
                }
            }
        }
    }
}
#endif
