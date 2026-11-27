import Foundation

#if canImport(SwiftUI)
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct BrushPresetDescriptor: Identifiable, Sendable {
    public let id: UInt32
    public let name: String
    public let trackBadge: String
    public let defaultSize: Double
    public let baseOpacity: Double
    public let hardness: Float
    public let isEraser: Bool

    public init(
        id: UInt32,
        name: String,
        trackBadge: String,
        defaultSize: Double = 6.0,
        baseOpacity: Double = 1.0,
        hardness: Float = 0.92,
        isEraser: Bool = false
    ) {
        self.id = id
        self.name = name
        self.trackBadge = trackBadge
        self.defaultSize = defaultSize
        self.baseOpacity = baseOpacity
        self.hardness = hardness
        self.isEraser = isEraser
    }
}

extension LayerBlendMode {
    /// Maps all 22 Rust `BlendMode` values to SwiftUI `GraphicsContext.BlendMode`.
    public var swiftUIBlendMode: GraphicsContext.BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .glowDodge: return .plusLighter
        case .linearBurn: return .colorBurn
        case .hardLight: return .hardLight
        case .softLight: return .softLight
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorBurn: return .colorBurn
        case .colorDodge: return .colorDodge
        case .add: return .plusLighter
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .vividLight: return .hardLight
        case .darkerColor: return .darken
        case .lighterColor: return .lighten
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

/// `S2 v1.0.0-rc3` — `雕龙 / DracoNib` ibisPaint-aligned Real RGBA8 Raster Studio Stage:
/// - Real Rust `LayerStack` RGBA8 pixel compositing (`CGImage`) with 22 blend modes & clipping masks.
/// - 16 ibisPaint brushes + Force Fade + Rope Stabilizer + real transparent Eraser / Smudge / Blur.
/// - Focused Per-Tool Tuning Bar, Interactive Lasso/Marquee Selection Action Bar, 2-Finger/Hand Canvas Panning,
///   High-Contrast Eyedropper Loupe, and 1-Tap Dual Novel+Manga Split View.
public struct MangaCanvasStageView: View {
    @ObservedObject public var controller: StudioWorkspaceController
    public let layout: WorkspaceLayoutHintKind

    @State private var lastDragCanvasPoint: CGPoint?
    @State private var strokeAnchorCanvasPoint: CGPoint?
    @State private var stabilizedPoint: CGPoint?
    @State private var strokePointCount: Int = 0
    @State private var dragStartNorm: CGPoint?
    @State private var dragCurrentNorm: CGPoint?
    @State private var shapeStartCanvas: CGPoint?
    @State private var shapeEndCanvas: CGPoint?
    @State private var activeLassoNorm: [CGPoint] = []
    @State private var activeLassoCanvas: [CGPoint] = []
    @State private var eyedropperLoupePos: CGPoint?
    @State private var panDragPrevViewPt: CGPoint?
    @State private var pinchBaseZoom: Double?
    @State private var canvasDimensions: String = "800 × 1132 (B4 Live RGBA8)"
    @State private var statusLine: String = "Ready"

    // Phase 3: Interactive Transform, Reference Window & FX Filter Modal State
    @State private var transformDx: Double = 0
    @State private var transformDy: Double = 0
    @State private var transformScale: Double = 1.0
    @State private var transformRotDeg: Double = 0
    @State private var refWindowOffset: CGSize = CGSize(width: -16, height: 16)
    @State private var fxBlurRadius: Double = 4.0
    @State private var fxHueDeg: Double = 0.0
    @State private var fxSatDelta: Double = 0.0
    @State private var fxBrightDelta: Double = 0.0
    @State private var fxContrast: Double = 0.15
    @State private var fxExtractBlack: Double = 0.25
    @State private var fxExtractWhite: Double = 0.80
    @State private var fxStrokeWidth: Double = 4.0
    @State private var fxShadowDx: Double = 8.0
    @State private var fxShadowDy: Double = 8.0
    @State private var fxShadowBlur: Double = 4.0

    // Multi-Canvas Gallery & Native Photo Import State
    @State private var newCanvasTitle: String = "MangaPage"
    @State private var newCanvasWidthText: String = "1200"
    @State private var newCanvasHeightText: String = "1698"
    @State private var selectedSizePresetId: String = "b4"
    #if canImport(PhotosUI)
    @State private var photoLayerPickerItem: PhotosPickerItem? = nil
    @State private var photoRefPickerItem: PhotosPickerItem? = nil
    #endif

    private let starterPresets: [BrushPresetDescriptor] = [
        BrushPresetDescriptor(id: 0, name: "G-Pen (Hard)", trackBadge: "Ink", defaultSize: 6.0, baseOpacity: 1.0, hardness: 0.96),
        BrushPresetDescriptor(id: 1, name: "Maru-Pen (Fine)", trackBadge: "Fine", defaultSize: 3.5, baseOpacity: 1.0, hardness: 0.98),
        BrushPresetDescriptor(id: 2, name: "Dip Pen (Soft)", trackBadge: "Ink", defaultSize: 7.5, baseOpacity: 0.95, hardness: 0.80),
        BrushPresetDescriptor(id: 3, name: "Felt Tip (Hard)", trackBadge: "Pen", defaultSize: 10.0, baseOpacity: 1.0, hardness: 0.95),
        BrushPresetDescriptor(id: 4, name: "Felt Tip (Soft)", trackBadge: "Pen", defaultSize: 12.0, baseOpacity: 0.90, hardness: 0.65),
        BrushPresetDescriptor(id: 5, name: "Pencil 2B", trackBadge: "Sketch", defaultSize: 5.0, baseOpacity: 0.68, hardness: 0.55),
        BrushPresetDescriptor(id: 6, name: "Pencil 6B", trackBadge: "Sketch", defaultSize: 8.0, baseOpacity: 0.82, hardness: 0.45),
        BrushPresetDescriptor(id: 7, name: "Charcoal Grain", trackBadge: "Dry", defaultSize: 14.0, baseOpacity: 0.72, hardness: 0.35),
        BrushPresetDescriptor(id: 8, name: "Flat Cel Marker", trackBadge: "Cel", defaultSize: 20.0, baseOpacity: 1.0, hardness: 0.98),
        BrushPresetDescriptor(id: 9, name: "Round Brush", trackBadge: "Paint", defaultSize: 18.0, baseOpacity: 0.88, hardness: 0.75),
        BrushPresetDescriptor(id: 10, name: "Airbrush (Soft)", trackBadge: "Air", defaultSize: 36.0, baseOpacity: 0.25, hardness: 0.08),
        BrushPresetDescriptor(id: 11, name: "Airbrush (Triangle)", trackBadge: "Air", defaultSize: 28.0, baseOpacity: 0.35, hardness: 0.20),
        BrushPresetDescriptor(id: 12, name: "Watercolor Bleed", trackBadge: "Wet", defaultSize: 22.0, baseOpacity: 0.52, hardness: 0.30),
        BrushPresetDescriptor(id: 13, name: "Oil Paint (Rough)", trackBadge: "Paint", defaultSize: 24.0, baseOpacity: 0.92, hardness: 0.68),
        BrushPresetDescriptor(id: 14, name: "Pixel Art 1px", trackBadge: "Dot", defaultSize: 2.0, baseOpacity: 1.0, hardness: 1.0),
        BrushPresetDescriptor(id: 15, name: "Soft / Hard Eraser", trackBadge: "Clean", defaultSize: 18.0, baseOpacity: 1.0, hardness: 0.88, isEraser: true),
    ]

    public init(
        controller: StudioWorkspaceController,
        layout: WorkspaceLayoutHintKind
    ) {
        self.controller = controller
        self.layout = layout
    }

    public var body: some View {
        HStack(spacing: 0) {
            ibisToolRail

            if layout != .singlePaneCompact {
                leftQuickCaliperStrip
            }

            VStack(spacing: 0) {
                focusedToolTuningBar
                if controller.s2Tool == .transform {
                    Divider().background(SuiteColorTokens.mangaBorder)
                    transformInteractiveBar
                }
                if controller.s2HasActiveSelection {
                    Divider().background(SuiteColorTokens.mangaBorder)
                    activeSelectionWorkflowBar
                }
                Divider().background(SuiteColorTokens.mangaBorder)
                canvasViewport
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if layout != .singlePaneCompact {
                if controller.s2ShowLayerDrawer {
                    CelLayerDrawerView(
                        layers: $controller.s2CelLayers,
                        selectedLayerId: $controller.s2SelectedLayerId,
                        onAddLayer: { controller.addLayer() },
                        onDuplicateLayer: { controller.duplicateSelectedLayer() },
                        onDeleteLayer: { controller.deleteSelectedLayer() },
                        onMergeDown: { controller.mergeSelectedLayerDown() },
                        onMoveLayer: { id, up in controller.moveLayer(id: id, up: up) },
                        onClearLayer: { controller.clearCurrentLayer() },
                        onUpdateLayer: { item in
                            controller.syncLayerToRust(item)
                            controller.refreshCompositeImage()
                            controller.markDirtyAndScheduleSave()
                        }
                    )
                    .frame(width: 272)
                } else if controller.s2ShowBrushDrawer {
                    brushAndColorInspectorDrawer
                        .frame(width: 272)
                }
            }
        }
        .background(SuiteColorTokens.mangaCharcoal)
        .sheet(item: $controller.s2PendingFilter) { fx in
            fxFilterSheetView(fx: fx)
        }
        .sheet(isPresented: $controller.s2ShowCanvasGallery) {
            canvasGallerySheetView
        }
        #if canImport(PhotosUI)
        .onChange(of: photoLayerPickerItem) { _, newItem in
            guard let item = newItem else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if controller.importImageDataAsNewLayer(data, layerName: "Photo_Layer") {
                        controller.s2ShowCanvasGallery = false
                    }
                    statusLine = controller.lastStatusBanner
                }
                photoLayerPickerItem = nil
            }
        }
        .onChange(of: photoRefPickerItem) { _, newItem in
            guard let item = newItem else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    if controller.importReferenceImageData(data) {
                        controller.s2ShowCanvasGallery = false
                    }
                    statusLine = controller.lastStatusBanner
                }
                photoRefPickerItem = nil
            }
        }
        #endif
        .onAppear {
            controller.ensureRustCanvasAndLayersInitialized()
            controller.refreshCanvasGallery()
            refreshCanvasDimsLabel()
        }
    }

    // MARK: - Left 56px ibisPaint-Aligned Tool Rail

    private var ibisToolRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                // 1-Tap Multi-Canvas Gallery & New Canvas Presets
                Button {
                    controller.refreshCanvasGallery()
                    controller.s2ShowCanvasGallery = true
                } label: {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 34)
                        .background(SuiteColorTokens.hubAccent.opacity(0.26))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(SuiteColorTokens.hubAccent.opacity(0.65), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("多画布画廊 / 新建画布 / 导入图片 (Gallery)")

                Divider().background(SuiteColorTokens.mangaBorder).padding(.horizontal, 8)

                ForEach(S2DrawingToolKind.allCases) { tool in
                    let selected = controller.s2Tool == tool
                    Button {
                        controller.selectTool(tool)
                        statusLine = "当前工具: \(tool.displayName)"
                    } label: {
                        Image(systemName: tool.systemSymbol)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 36)
                            .background(selected ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.05))
                            .foregroundStyle(selected ? .white : Color.white.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selected ? Color.white.opacity(0.55) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(tool.displayName)
                }

                Divider().background(SuiteColorTokens.mangaBorder).padding(.horizontal, 8)

                // Quick 1-Tap Dual Novel + Canvas Split Toggle directly in tool rail
                Button {
                    controller.toggleDualNovelMangaStudio()
                } label: {
                    Image(systemName: "rectangle.split.2x1.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 36)
                        .background(controller.workspaceMode == .dualNovelManga ? SuiteColorTokens.novelAccent : Color.white.opacity(0.05))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("同屏打开小说与画布 (S2+S3 Dual Split)")

                // Inspector & Layer Drawer toggles
                Button {
                    controller.s2ShowLayerDrawer = false
                    controller.s2ShowBrushDrawer.toggle()
                } label: {
                    SuiteVectorIcon(.mangaStabilizer, size: 18)
                        .frame(width: 40, height: 36)
                        .background(controller.s2ShowBrushDrawer && !controller.s2ShowLayerDrawer ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.05))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Brush & Color Inspector")

                Button {
                    controller.s2ShowLayerDrawer.toggle()
                } label: {
                    SuiteVectorIcon(.mangaLayers, size: 18)
                        .frame(width: 40, height: 36)
                        .background(controller.s2ShowLayerDrawer ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.05))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Cel Layers (L)")
            }
            .padding(.vertical, 10)
        }
        .frame(width: 56)
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .trailing) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    // MARK: - ibisPaint Signature Left Quick Caliper (Color + Size + Opacity, Non-Overlapping)

    private var leftQuickCaliperStrip: some View {
        VStack(spacing: 12) {
            // Active Color Swatch + Native HSB Color Picker
            VStack(spacing: 3) {
                ColorPicker("", selection: activeColorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 30, height: 30)
                    .help("Active Foreground Color (\(controller.s2ActiveColor.hexString))")
                Text(controller.s2ActiveColor.hexString)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)
            }

            VStack(spacing: 4) {
                Text("\(Int(controller.s2BrushSize))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Slider(value: $controller.s2BrushSize, in: 1...100)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 24)
                    .frame(width: 24, height: 100)
                    .tint(SuiteColorTokens.mangaAccent)
                Text("PX")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            VStack(spacing: 4) {
                Text("\(Int(controller.s2BrushOpacity * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Slider(value: $controller.s2BrushOpacity, in: 0.05...1.0)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 24)
                    .frame(width: 24, height: 100)
                    .tint(SuiteColorTokens.hubAccent)
                Text("OP")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }

            Spacer(minLength: 4)

            // Quick recent color dots
            VStack(spacing: 5) {
                ForEach(controller.s2RecentColors.prefix(5), id: \.hexString) { swatch in
                    Button {
                        controller.setActiveColor(swatch)
                        statusLine = "Color: \(swatch.hexString)"
                    } label: {
                        Circle()
                            .fill(swatch.swiftUIColor)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(
                                    swatch == controller.s2ActiveColor ? Color.white : Color.white.opacity(0.25),
                                    lineWidth: swatch == controller.s2ActiveColor ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 10)
        .frame(width: 48)
        .background(SuiteColorTokens.mangaPanel.opacity(0.92))
        .overlay(alignment: .trailing) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    // MARK: - Fix #2: Dedicated Per-Tool Focused Tuning Bar (Shows ONLY Controls for the Active Tool)

    private var activePresetName: String {
        starterPresets.first(where: { $0.id == controller.s2PresetIndex })?.name ?? "G-Pen"
    }

    private var focusedToolTuningBar: some View {
        HStack(spacing: 10) {
            // Left: Active Tool Pill + Dedicated Focused Tuning Controls for THIS tool only
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Tool badge
                    HStack(spacing: 5) {
                        Image(systemName: controller.s2Tool.systemSymbol)
                            .font(.caption.bold())
                        Text(controller.s2Tool.displayName)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SuiteColorTokens.mangaAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)

                    // Strictly tool-specific performance & tuning parameters
                    focusedControlsForCurrentTool
                }
                .padding(.vertical, 2)
            }
            .layoutPriority(1)

            // Right: Essential Viewport, Dual-Split & Undo/Redo Cluster
            HStack(spacing: 7) {
                // Studio Extras Menu (keeps FX, Screentone, Reference, Export organized & out of the way)
                Menu {
                    Section("Studio Actions") {
                        Button("画廊 / 新建画布 / 导入图片 (Gallery)") {
                            controller.refreshCanvasGallery()
                            controller.s2ShowCanvasGallery = true
                        }
                        Button("Apply 60 LPI Screentone") {
                            _ = controller.applyScreentoneFill()
                            statusLine = controller.lastStatusBanner
                        }
                        Button(controller.s2ShowReferenceWindow ? "Hide Reference Window" : "Show Reference Window") {
                            controller.s2ShowReferenceWindow.toggle()
                        }
                        Button(controller.s2MirrorHorizontal ? "Disable Mirror Preview" : "Mirror Canvas Horizontally (H)") {
                            controller.s2MirrorHorizontal.toggle()
                        }
                        Button("重置画布旋转 (0°)") {
                            controller.resetRotation()
                            statusLine = "画布角度已重置 0°"
                        }
                    }
                    Section("Layer FX Filters") {
                        ForEach(S2FilterActionKind.allCases) { fx in
                            Button(fx.displayName) {
                                controller.s2PendingFilter = fx
                            }
                        }
                    }
                    #if os(iOS)
                    Section("Touch & Export") {
                        Button(controller.s2ApplePencilOnlyDraw ? "✓ Apple Pencil Only (Finger Pans)" : "Apple Pencil Only (Finger Pans)") {
                            controller.s2ApplePencilOnlyDraw.toggle()
                        }
                        Button("Export PNG to Files") {
                            _ = controller.exportCanvasPng(to: nil, transparentBackground: controller.s2Backdrop != .whitePaper)
                            statusLine = controller.lastStatusBanner
                        }
                        Button("Export PSD (8BPS) to Files") {
                            _ = controller.exportCanvasPsd(to: nil)
                            statusLine = controller.lastStatusBanner
                        }
                    }
                    #endif
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                        Text("More")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    controller.selectTool(controller.s2Tool == .handPan ? .brush : .handPan)
                } label: {
                    Image(systemName: "hand.draw.fill")
                        .font(.caption)
                        .padding(5)
                        .background(controller.s2Tool == .handPan ? SuiteColorTokens.hubAccent : Color.white.opacity(0.10))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("拖动移动画布 (Hand Pan Tool)")

                Button {
                    controller.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button("\(Int(controller.s2ViewportZoom * 100))%") {
                    controller.resetViewport()
                }
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .help("重置画布缩放与居中 (Reset Zoom & Pan)")

                Button {
                    controller.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 14).background(SuiteColorTokens.mangaBorder)

                Button("Undo") { controller.performUndoStroke() }
                    .disabled(!controller.canUndoInCurrentContext)
                    .font(.caption.bold())
                    .foregroundStyle(controller.canUndoInCurrentContext ? .white : Color.white.opacity(0.3))
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)

                Button("Redo") { controller.performRedoStroke() }
                    .disabled(!controller.canRedoInCurrentContext)
                    .font(.caption.bold())
                    .foregroundStyle(controller.canRedoInCurrentContext ? .white : Color.white.opacity(0.3))
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SuiteColorTokens.mangaPanel)
    }

    @ViewBuilder
    private var focusedControlsForCurrentTool: some View {
        switch controller.s2Tool {
        case .brush:
            // Focused Brush Controls: Preset, Size, Opacity, Stabilizer, Force Fade, Shape
            Menu {
                ForEach(starterPresets.filter { !$0.isEraser }) { preset in
                    Button("\(preset.name) [\(preset.trackBadge)]") {
                        controller.s2PresetIndex = preset.id
                        controller.s2BrushSize = preset.defaultSize
                        controller.s2BrushOpacity = preset.baseOpacity
                    }
                }
            } label: {
                focusedPillLabel(title: "笔刷: \(activePresetName)", icon: "paintbrush.pointed.fill")
            }
            .fixedSize(horizontal: true, vertical: false)

            focusedSliderCluster(
                label: "粗细 \(Int(controller.s2BrushSize))px",
                value: $controller.s2BrushSize,
                range: 1...100,
                width: 84
            )

            focusedSliderCluster(
                label: "不透明度 \(Int(controller.s2BrushOpacity * 100))%",
                value: $controller.s2BrushOpacity,
                range: 0.05...1.0,
                width: 76
            )

            focusedSliderCluster(
                label: "抖动修正 \(Int(controller.s2StabilizerPx))",
                value: $controller.s2StabilizerPx,
                range: 0...24,
                width: 72
            )

            Toggle("起笔渐细", isOn: $controller.s2ForceFade)
                .toggleStyle(.button)
                .font(.caption2.bold())
                .tint(SuiteColorTokens.mangaAccent)
                .fixedSize(horizontal: true, vertical: false)

            Menu {
                ForEach(S2ShapeAssistKind.allCases) { shape in
                    Button(shape.displayName) { controller.s2ShapeAssist = shape }
                }
            } label: {
                focusedPillLabel(title: "形状: \(controller.s2ShapeAssist.displayName)", icon: "square.on.circle")
            }
            .fixedSize(horizontal: true, vertical: false)

        case .eraser:
            // Focused Eraser Controls: Size, Strength/Opacity, Stabilizer, Clear Layer
            focusedSliderCluster(
                label: "橡皮大小 \(Int(controller.s2BrushSize))px",
                value: $controller.s2BrushSize,
                range: 1...100,
                width: 96
            )

            focusedSliderCluster(
                label: "擦除力度 \(Int(controller.s2BrushOpacity * 100))%",
                value: $controller.s2BrushOpacity,
                range: 0.05...1.0,
                width: 84
            )

            focusedSliderCluster(
                label: "稳定器 \(Int(controller.s2StabilizerPx))",
                value: $controller.s2StabilizerPx,
                range: 0...24,
                width: 72
            )

            Button {
                controller.clearCurrentLayer()
                statusLine = controller.lastStatusBanner
            } label: {
                focusedPillLabel(title: "清空当前图层", icon: "trash")
            }
            .buttonStyle(.plain)

        case .smudge, .blur:
            // Focused Smudge / Blur Controls: Radius, Strength, Stabilizer
            focusedSliderCluster(
                label: "作用半径 \(Int(controller.s2BrushSize))px",
                value: $controller.s2BrushSize,
                range: 2...80,
                width: 96
            )

            focusedSliderCluster(
                label: "混色强度 \(Int(controller.s2BrushOpacity * 100))%",
                value: $controller.s2BrushOpacity,
                range: 0.05...1.0,
                width: 88
            )

            focusedSliderCluster(
                label: "平滑 \(Int(controller.s2StabilizerPx))",
                value: $controller.s2StabilizerPx,
                range: 0...24,
                width: 72
            )

        case .bucket:
            // Focused Bucket Fill Controls: Active Color, Close-Gap, Expand, Tolerance
            ColorPicker("", selection: activeColorBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 22, height: 22)

            focusedIntStepperCluster(
                title: "封口间隙 Gap: \(controller.s2BucketCloseGapPx)px",
                value: $controller.s2BucketCloseGapPx,
                range: 0...15
            )

            focusedIntStepperCluster(
                title: "扩张 Expand: +\(controller.s2BucketExpandPx)px",
                value: $controller.s2BucketExpandPx,
                range: 0...8
            )

            Text("点按闭合线稿区域即可自动封口填色")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.75))
                .fixedSize(horizontal: true, vertical: false)

        case .eyedropper:
            // Focused Eyedropper Controls: Live Picked Color Swatch + Hex + RGB + Auto-switch to Brush
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .fill((controller.s2EyedropperPreview ?? controller.s2ActiveColor).swiftUIColor)
                    .frame(width: 24, height: 20)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white, lineWidth: 1.5))

                let c = controller.s2EyedropperPreview ?? controller.s2ActiveColor
                Text("当前提取: \(c.hexString) (RGB \(c.r),\(c.g),\(c.b))")
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())

            Toggle("吸色后自动切回画笔", isOn: $controller.s2EyedropperAutoSwitchToBrush)
                .toggleStyle(.button)
                .font(.caption2.bold())
                .tint(SuiteColorTokens.hubAccent)
                .fixedSize(horizontal: true, vertical: false)

            Text("在画布上点按或拖动即可实时提取图层合成颜色")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: true, vertical: false)

        case .lasso, .rectSelect:
            // Focused Lasso & Marquee Selection Guide + Quick Actions
            if !controller.s2HasActiveSelection {
                HStack(spacing: 6) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.caption2)
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                    Text("第1步: 在画布上拖动圈出选区 → 第2步: 在弹出选区栏中【填色/擦除/扩缩/变形/网点】")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(SuiteColorTokens.hubAccent.opacity(0.22))
                .clipShape(Capsule())
            } else {
                Text("已选中 \(controller.s2SelectionPixelCount) px · 请使用下方选区调整栏操作，或直接重新圈选")
                    .font(.caption2.bold())
                    .foregroundStyle(SuiteColorTokens.hubAccent)
                    .fixedSize(horizontal: true, vertical: false)
            }

        case .magicWand:
            // Focused Magic Wand Tolerance Slider
            focusedIntSliderCluster(
                label: "魔棒容差 Tolerance: \(controller.s2BucketTolerance)",
                value: $controller.s2BucketTolerance,
                range: 0...128,
                width: 96
            )

            Text("点按画布色块自动选中相近颜色区域")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: true, vertical: false)

        case .handPan:
            // Focused Hand / Move Canvas Controls
            HStack(spacing: 6) {
                Text("位移 (\(Int(controller.s2PanOffset.width)), \(Int(controller.s2PanOffset.height)))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)

                Button("← 左移") { controller.panCanvas(by: CGSize(width: -60, height: 0)) }
                    .buttonStyle(FocusedActionPillStyle())
                Button("→ 右移") { controller.panCanvas(by: CGSize(width: 60, height: 0)) }
                    .buttonStyle(FocusedActionPillStyle())
                Button("↑ 上移") { controller.panCanvas(by: CGSize(width: 0, height: -60)) }
                    .buttonStyle(FocusedActionPillStyle())
                Button("↓ 下移") { controller.panCanvas(by: CGSize(width: 0, height: 60)) }
                    .buttonStyle(FocusedActionPillStyle())

                Button("居中归位") {
                    controller.resetViewport()
                    statusLine = "画布已居中归位 (100%)"
                }
                .buttonStyle(FocusedActionPillStyle(accent: SuiteColorTokens.hubAccent))
            }

            #if os(iOS)
            Toggle("单指移画布/仅Pencil绘画", isOn: $controller.s2ApplePencilOnlyDraw)
                .toggleStyle(.button)
                .font(.caption2.bold())
                .tint(SuiteColorTokens.novelAccent)
                .fixedSize(horizontal: true, vertical: false)
            #endif

        case .transform:
            Text("在下方【自由变换栏】调整位移(dX/dY)、缩放(Scale)、旋转(Rotate)或翻转图层")
                .font(.caption2.bold())
                .foregroundStyle(SuiteColorTokens.hubAccent)
                .fixedSize(horizontal: true, vertical: false)

        case .ruler:
            // Focused Ruler Mode Picker
            ForEach(RulerModeKind.allCases) { mode in
                let active = controller.s2RulerMode == mode
                Button {
                    controller.s2RulerMode = mode
                    statusLine = "尺规模式: \(mode.displayName)"
                } label: {
                    Text(mode.displayName)
                        .font(.caption2.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(active ? SuiteColorTokens.hubAccent : Color.white.opacity(0.10))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }

            Button("切回画笔绘画 →") {
                controller.selectTool(.brush)
            }
            .buttonStyle(FocusedActionPillStyle(accent: SuiteColorTokens.mangaAccent))

        case .panelKnife:
            // Focused Panel Knife Gutter Width Controls
            focusedSliderCluster(
                label: "分格间距 Gutter \(Int(controller.s2PanelGutterPx))px",
                value: $controller.s2PanelGutterPx,
                range: 4...36,
                width: 96
            )

            Text("已切分 \(controller.s2PanelCount) 格 · 在画布上划过即可分割漫画分镜框")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: true, vertical: false)

        case .textBubble:
            Text("点按画布放置台词气泡 (\(controller.s2SpeechBubbles.count) 个) · 可切换横排/竖排与直接输入台词")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: true, vertical: false)

            if !controller.s2SpeechBubbles.isEmpty {
                Button("移除最后一个气泡") {
                    if let last = controller.s2SpeechBubbles.last {
                        controller.removeSpeechBubble(id: last.id)
                    }
                }
                .buttonStyle(FocusedActionPillStyle())
            }
        }
    }

    // MARK: - Fix #1: Clear Step-by-Step Selection Adjustment & Action Bar (Lasso / Marquee / Magic Wand)

    private var activeSelectionWorkflowBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "lasso.badge.sparkles")
                        .font(.caption2.bold())
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                    Text("选区已激活 (\(controller.s2SelectionPixelCount) px):")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    let count = controller.fillActiveSelectionWithCurrentColor()
                    statusLine = "已在选区内填充当前颜色 (\(count) px)"
                } label: {
                    Label("填色 Fill", systemImage: "paintbrush.fill")
                }
                .buttonStyle(FocusedActionPillStyle(accent: SuiteColorTokens.mangaAccent))

                Button {
                    let count = controller.eraseActiveSelectionPixels()
                    statusLine = "已清除选区内像素 (\(count) px)"
                } label: {
                    Label("清除 Erase", systemImage: "eraser.fill")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    let count = controller.adjustActiveSelectionBorder(deltaPx: 6.0)
                    statusLine = "选区已向外扩大 +6px (\(count) px)"
                } label: {
                    Label("扩大 +6px", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    let count = controller.adjustActiveSelectionBorder(deltaPx: -6.0)
                    statusLine = "选区已向内收缩 -6px (\(count) px)"
                } label: {
                    Label("收缩 -6px", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    controller.invertCanvasSelection()
                    statusLine = "已反选选区 Invert Selection"
                } label: {
                    Label("反选 Invert", systemImage: "circle.lefthalf.filled")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    _ = controller.applyScreentoneFill()
                    statusLine = controller.lastStatusBanner
                } label: {
                    Label("贴网点 Tone", systemImage: "circle.grid.3x3.fill")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    controller.selectTool(.brush)
                    statusLine = "已切到画笔：现在绘画将仅作用在选区内部"
                } label: {
                    Label("在选区内绘画", systemImage: "pencil.tip")
                }
                .buttonStyle(FocusedActionPillStyle(accent: SuiteColorTokens.hubAccent))

                Button {
                    controller.selectTool(.transform)
                    statusLine = "已开启自由变换栏"
                } label: {
                    Label("变换图层", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .buttonStyle(FocusedActionPillStyle())

                Button {
                    controller.clearCanvasSelection()
                    statusLine = "已取消选区 Deselected"
                } label: {
                    Label("取消选区", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(FocusedActionPillStyle(accent: Color.red.opacity(0.75)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(SuiteColorTokens.mangaPanel.opacity(0.96))
    }

    // MARK: - Focused Bar Subcomponents

    private func focusedPillLabel(title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(title)
                .font(.caption2.bold())
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.11))
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func focusedSliderCluster(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        width: CGFloat
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
            Slider(value: value, in: range)
                .frame(width: width)
                .tint(SuiteColorTokens.mangaAccent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func focusedIntSliderCluster(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        width: CGFloat
    ) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        return focusedSliderCluster(
            label: label,
            value: doubleBinding,
            range: Double(range.lowerBound)...Double(range.upperBound),
            width: width
        )
    }

    private func focusedIntStepperCluster(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 4) {
            Button("−") {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }
            .font(.caption.bold())
            .frame(width: 20, height: 20)
            .background(Color.white.opacity(0.14))
            .foregroundStyle(.white)
            .clipShape(Circle())
            .buttonStyle(.plain)

            Text(title)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)

            Button("+") {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            }
            .font(.caption.bold())
            .frame(width: 20, height: 20)
            .background(Color.white.opacity(0.14))
            .foregroundStyle(.white)
            .clipShape(Circle())
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private struct FocusedActionPillStyle: ButtonStyle {
        var accent: Color = Color.white.opacity(0.13)

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.caption2.bold())
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(configuration.isPressed ? accent.opacity(0.65) : accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Phase 3: Interactive Transform Bar (`T`)

    private var transformInteractiveBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if controller.s2HasActiveSelection {
                    Button {
                        controller.s2TransformSelectionOnly.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: controller.s2TransformSelectionOnly ? "lasso.badge.sparkles" : "square.stack.3d.up")
                                .font(.caption2)
                            Text(controller.s2TransformSelectionOnly ? "选区局部变形" : "整层变形")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(controller.s2TransformSelectionOnly ? SuiteColorTokens.hubAccent : Color.white.opacity(0.14))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)

                    if controller.s2TransformSelectionOnly {
                        Button {
                            controller.s2TransformKeepOriginal.toggle()
                        } label: {
                            Text(controller.s2TransformKeepOriginal ? "✓ 保留原图(复制)" : "剪切移动")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(controller.s2TransformKeepOriginal ? SuiteColorTokens.novelAccent : Color.white.opacity(0.10))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                } else {
                    Text("整层自由变形")
                        .font(.caption2.bold())
                        .foregroundStyle(SuiteColorTokens.mangaAccent)
                        .fixedSize(horizontal: true, vertical: false)
                }

                HStack(spacing: 4) {
                    Text("dX \(Int(transformDx))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                    Slider(value: $transformDx, in: -300...300).frame(width: 72)
                }
                HStack(spacing: 4) {
                    Text("dY \(Int(transformDy))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                    Slider(value: $transformDy, in: -300...300).frame(width: 72)
                }
                HStack(spacing: 4) {
                    Text(String(format: "%.2fx", transformScale))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                    Slider(value: $transformScale, in: 0.25...2.5).frame(width: 72)
                }
                HStack(spacing: 4) {
                    Text("\(Int(transformRotDeg))°")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: true, vertical: false)
                    Slider(value: $transformRotDeg, in: -180...180).frame(width: 72)
                }

                Button("Flip H") { controller.flipSelectedLayer(horizontal: true) }
                    .font(.caption2.bold())
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.white.opacity(0.10)).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5)).buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)

                Button("Flip V") { controller.flipSelectedLayer(horizontal: false) }
                    .font(.caption2.bold())
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.white.opacity(0.10)).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5)).buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)

                Button(controller.s2HasActiveSelection && controller.s2TransformSelectionOnly ? "应用局部变形" : "Apply") {
                    _ = controller.applyAffineTransform(
                        dx: Float(transformDx),
                        dy: Float(transformDy),
                        scaleX: Float(transformScale),
                        scaleY: Float(transformScale),
                        rotDeg: Float(transformRotDeg),
                        selectionOnly: controller.s2TransformSelectionOnly,
                        clearSource: !controller.s2TransformKeepOriginal
                    )
                    transformDx = 0; transformDy = 0; transformScale = 1.0; transformRotDeg = 0
                    statusLine = controller.lastStatusBanner
                }
                .font(.caption2.bold())
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(SuiteColorTokens.mangaAccent).foregroundStyle(.white)
                .clipShape(Capsule()).buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)

                Button("Reset") {
                    transformDx = 0; transformDy = 0; transformScale = 1.0; transformRotDeg = 0
                }
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.7))
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(SuiteColorTokens.mangaPanel.opacity(0.95))
    }

    // MARK: - Real Rust RGBA8 Composited Canvas Viewport (With Pan Pad, Selection HUD & Eyedropper Loupe)

    private var canvasAspectRatio: CGFloat {
        let w = CGFloat(max(1, controller.s2CanvasPixelWidth))
        let h = CGFloat(max(1, controller.s2CanvasPixelHeight))
        return w / h
    }

    private var canvasViewport: some View {
        GeometryReader { outerGeo in
            ZStack(alignment: .topTrailing) {
                ZStack {
                    SuiteColorTokens.mangaCharcoal

                    ZStack {
                        canvasBackdropView

                        #if canImport(CoreGraphics)
                        if let cgImage = controller.s2CompositeImage {
                            Image(decorative: cgImage, scale: 1.0)
                                .resizable()
                                .interpolation(.medium)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        #endif

                        // Vector overlay strictly for active ruler guides, marching-ants selection & shape/knife preview
                        Canvas { context, size in
                            renderActiveRulerGuide(in: &context, size: size)
                            renderSelectionOverlay(in: &context, size: size)
                            renderLiveShapeOrKnifePreview(in: &context, size: size)
                        }
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Editable manga speech bubbles overlay
                        GeometryReader { bubbleGeo in
                            ForEach($controller.s2SpeechBubbles) { $bubble in
                                speechBubbleView(bubble: $bubble, canvasSize: bubbleGeo.size)
                            }
                        }

                        // High-Contrast Eyedropper Loupe (Works on both iPadOS UIKit Touch & macOS Drag!)
                        GeometryReader { loupeGeo in
                            if let norm = controller.s2EyedropperLoupeNorm,
                               let preview = controller.s2EyedropperPreview
                            {
                                let lx = norm.x * loupeGeo.size.width
                                let ly = norm.y * loupeGeo.size.height
                                eyedropperLoupeHUD(color: preview)
                                    .position(x: lx, y: max(42, ly - 52))
                                    .allowsHitTesting(false)
                            } else if let loupePos = eyedropperLoupePos,
                                      let preview = controller.s2EyedropperPreview
                            {
                                eyedropperLoupeHUD(color: preview)
                                    .position(x: loupePos.x, y: max(42, loupePos.y - 52))
                                    .allowsHitTesting(false)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .aspectRatio(canvasAspectRatio, contentMode: .fit)
                    .overlay {
                        #if os(iOS)
                        ApplePencilCanvasOverlayView(
                            controller: controller,
                            presetHardness: activePresetHardness
                        ) { msg in
                            statusLine = msg
                        }
                        .allowsHitTesting(controller.s2Tool != .textBubble || controller.s2SpeechBubbles.isEmpty)
                        #else
                        GeometryReader { canvasGeo in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleCanvasDragChanged(
                                                at: value.location,
                                                canvasViewSize: canvasGeo.size
                                            )
                                        }
                                        .onEnded { value in
                                            handleCanvasDragEnded(
                                                at: value.location,
                                                canvasViewSize: canvasGeo.size
                                            )
                                        }
                                )
                        }
                        .allowsHitTesting(controller.s2Tool != .textBubble || controller.s2SpeechBubbles.isEmpty)
                        #endif
                    }
                    .scaleEffect(
                        x: controller.s2ViewportZoom * (controller.s2MirrorHorizontal ? -1.0 : 1.0),
                        y: controller.s2ViewportZoom
                    )
                    .rotationEffect(.degrees(controller.s2RotationDeg))
                    .offset(controller.s2PanOffset)
                    .padding(18)
                    .frame(maxWidth: outerGeo.size.width, maxHeight: outerGeo.size.height)
                }

                if controller.s2ShowReferenceWindow {
                    floatingReferenceWindow
                        .offset(refWindowOffset)
                }

                // Bottom-Right Floating Canvas Navigation D-Pad (Left/Right/Up/Down Pan + Center Reset)
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        // Bottom-Left status & gesture tip badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(controller.s2ActiveColor.swiftUIColor)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
                            Text(statusLine)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SuiteColorTokens.mangaPanel.opacity(0.88))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))

                        Spacer()

                        floatingCanvasPanControlPad
                    }
                    .padding(12)
                }
            }
            #if !os(iOS)
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let base = pinchBaseZoom ?? controller.s2ViewportZoom
                        if pinchBaseZoom == nil { pinchBaseZoom = base }
                        controller.s2ViewportZoom = min(max(base * Double(scale), 0.2), 8.0)
                    }
                    .onEnded { _ in
                        pinchBaseZoom = nil
                    }
            )
            #endif
        }
        .clipped()
    }

    // MARK: - Fix #5: High-Contrast Eyedropper Loupe HUD

    private func eyedropperLoupeHUD(color: PersistedRGBA) -> some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor)
                    .frame(width: 54, height: 54)
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 54, height: 54)
                Circle()
                    .strokeBorder(Color.black.opacity(0.6), lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Int(color.r) + Int(color.g) + Int(color.b) > 380 ? Color.black : Color.white)
            }
            Text(color.hexString)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.82))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
    }

    // MARK: - Fix #3 + #2: Floating On-Canvas Pan, Rotation & Center Control Pad

    private var floatingCanvasPanControlPad: some View {
        VStack(spacing: 5) {
            // Compact Canvas Rotation Strip (-15° / Live Angle Reset / +15°)
            HStack(spacing: 4) {
                Button {
                    controller.rotateCanvas(by: -15.0)
                    statusLine = "画布旋转 \(Int(controller.s2RotationDeg.rounded()))°"
                } label: {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 22)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("画布逆时针旋转 15°")

                Button {
                    controller.resetRotation()
                    statusLine = "画布角度已归零 (0°)"
                } label: {
                    Text("\(Int(controller.s2RotationDeg.rounded()))°")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .frame(minWidth: 36, minHeight: 22)
                        .padding(.horizontal, 4)
                        .background(abs(controller.s2RotationDeg) > 0.5 ? SuiteColorTokens.hubAccent : Color.white.opacity(0.10))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("点击恢复画布 0° 旋转（支持双指自由旋转）")

                Button {
                    controller.rotateCanvas(by: 15.0)
                    statusLine = "画布旋转 \(Int(controller.s2RotationDeg.rounded()))°"
                } label: {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 22)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("画布顺时针旋转 15°")
            }

            HStack(spacing: 4) {
                Button {
                    controller.panCanvas(by: CGSize(width: -70, height: 0))
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("画布左移")

                VStack(spacing: 4) {
                    Button {
                        controller.panCanvas(by: CGSize(width: 0, height: -70))
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.caption.bold())
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("画布上移")

                    Button {
                        controller.resetViewport()
                        statusLine = "画布已居中归位 (100% · 0°)"
                    } label: {
                        Text("居中")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 32, height: 22)
                            .background(SuiteColorTokens.mangaAccent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("重置画布位移、缩放与旋转")

                    Button {
                        controller.panCanvas(by: CGSize(width: 0, height: 70))
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.caption.bold())
                            .frame(width: 28, height: 26)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("画布下移")
                }

                Button {
                    controller.panCanvas(by: CGSize(width: 70, height: 0))
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("画布右移")
            }
        }
        .padding(6)
        .background(SuiteColorTokens.mangaPanel.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    }

    @ViewBuilder
    private var canvasBackdropView: some View {
        switch controller.s2Backdrop {
        case .whitePaper:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        case .transparentLight:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.92))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        case .transparentDark:
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.18))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        }
    }

    // MARK: - Right Brush & Color Inspector Drawer

    private var brushAndColorInspectorDrawer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Brushes (\(starterPresets.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(canvasDimensions)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }

                ForEach(starterPresets) { preset in
                    let active = preset.id == controller.s2PresetIndex
                    Button {
                        controller.s2PresetIndex = preset.id
                        controller.s2BrushSize = preset.defaultSize
                        controller.s2BrushOpacity = preset.baseOpacity
                        controller.s2Tool = preset.isEraser ? .eraser : .brush
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: preset.isEraser ? "eraser.fill" : "paintbrush.pointed.fill")
                                .font(.caption2)
                                .foregroundStyle(active ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.65))
                                .frame(width: 16)
                            Text(preset.name)
                                .font(.caption.weight(active ? .bold : .regular))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text(preset.trackBadge)
                                .font(.caption2.monospaced())
                                .foregroundStyle(active ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.55))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(active ? SuiteColorTokens.mangaAccent.opacity(0.20) : Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(active ? SuiteColorTokens.mangaAccent : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(SuiteColorTokens.mangaBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Swatches")
                        .font(.caption.bold())
                        .foregroundStyle(.white)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(controller.s2RecentColors, id: \.hexString) { swatch in
                            Button {
                                controller.setActiveColor(swatch)
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(swatch.swiftUIColor)
                                    .frame(height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(
                                                swatch == controller.s2ActiveColor ? Color.white : Color.white.opacity(0.2),
                                                lineWidth: swatch == controller.s2ActiveColor ? 2 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Backdrop")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.72))
                        Spacer()
                        Picker("Backdrop", selection: $controller.s2Backdrop) {
                            ForEach(S2CanvasBackdropKind.allCases) { bg in
                                Text(bg.displayName).tag(bg)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(SuiteColorTokens.mangaAccent)
                    }

                    HStack(spacing: 6) {
                        Text("Rotate \(Int(controller.s2RotationDeg))°")
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.white.opacity(0.72))
                        Spacer()
                        Button("-15°") { controller.s2RotationDeg -= 15 }
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .buttonStyle(.plain)
                        Button("0°") { controller.s2RotationDeg = 0 }
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .buttonStyle(.plain)
                        Button("+15°") { controller.s2RotationDeg += 15 }
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .buttonStyle(.plain)
                    }
                }

                Divider().background(SuiteColorTokens.mangaBorder)

                Text(statusLine)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    // MARK: - Coordinate Mapping & Live Rust Raster Tool Dispatch

    private var activePresetHardness: Float {
        starterPresets.first(where: { $0.id == controller.s2PresetIndex })?.hardness ?? 0.90
    }

    private func mapViewPointToCanvas(_ viewPt: CGPoint, viewSize: CGSize) -> (canvas: CGPoint, norm: CGPoint) {
        let safeW = max(1.0, viewSize.width)
        let safeH = max(1.0, viewSize.height)
        let nx = min(max(viewPt.x / safeW, 0.0), 1.0)
        let ny = min(max(viewPt.y / safeH, 0.0), 1.0)
        let cx = nx * CGFloat(controller.s2CanvasPixelWidth)
        let cy = ny * CGFloat(controller.s2CanvasPixelHeight)
        return (CGPoint(x: cx, y: cy), CGPoint(x: nx, y: ny))
    }

    private var activeColorBinding: Binding<Color> {
        Binding(
            get: { controller.s2ActiveColor.swiftUIColor },
            set: { newColor in
                #if canImport(AppKit)
                if let ns = NSColor(newColor).usingColorSpace(.sRGB) {
                    controller.setActiveColor(PersistedRGBA(
                        r: UInt8(max(0, min(255, Int(round(ns.redComponent * 255))))),
                        g: UInt8(max(0, min(255, Int(round(ns.greenComponent * 255))))),
                        b: UInt8(max(0, min(255, Int(round(ns.blueComponent * 255))))),
                        a: 255
                    ))
                }
                #elseif canImport(UIKit)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
                UIColor(newColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                controller.setActiveColor(PersistedRGBA(
                    r: UInt8(max(0, min(255, Int(round(r * 255))))),
                    g: UInt8(max(0, min(255, Int(round(g * 255))))),
                    b: UInt8(max(0, min(255, Int(round(b * 255))))),
                    a: 255
                ))
                #endif
            }
        )
    }

    private func refreshCanvasDimsLabel() {
        canvasDimensions = "\(controller.s2CanvasPixelWidth) × \(controller.s2CanvasPixelHeight) RGBA8"
    }

    private func handleCanvasDragChanged(at viewPoint: CGPoint, canvasViewSize: CGSize) {
        if controller.s2Tool == .handPan {
            if let prev = panDragPrevViewPt {
                controller.panCanvas(by: CGSize(
                    width: viewPoint.x - prev.x,
                    height: viewPoint.y - prev.y
                ))
            }
            panDragPrevViewPt = viewPoint
            return
        }

        let mapped = mapViewPointToCanvas(viewPoint, viewSize: canvasViewSize)
        let canvasPt = mapped.canvas
        let normPt = mapped.norm

        switch controller.s2Tool {
        case .eyedropper:
            eyedropperLoupePos = viewPoint
            controller.s2EyedropperLoupeNorm = normPt
            if let picked = controller.sampleEyedropper(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y)) {
                statusLine = "吸色预览 Eyedropper: \(picked.hexString) (RGB \(picked.r),\(picked.g),\(picked.b))"
            }
            return

        case .bucket, .magicWand, .textBubble, .transform, .handPan:
            return

        case .panelKnife:
            if dragStartNorm == nil {
                dragStartNorm = normPt
                shapeStartCanvas = canvasPt
                controller.s2LiveMarqueeStartNorm = normPt
            }
            dragCurrentNorm = normPt
            shapeEndCanvas = canvasPt
            controller.s2LiveMarqueeCurrentNorm = normPt
            return

        case .rectSelect:
            if dragStartNorm == nil {
                dragStartNorm = normPt
                controller.s2LiveMarqueeStartNorm = normPt
            }
            dragCurrentNorm = normPt
            controller.s2LiveMarqueeCurrentNorm = normPt
            return

        case .lasso:
            activeLassoNorm.append(normPt)
            activeLassoCanvas.append(canvasPt)
            controller.s2LiveLassoNorm = activeLassoNorm
            return

        case .brush, .eraser, .smudge, .blur:
            if controller.s2Tool == .brush && controller.s2ShapeAssist != .freehand {
                if dragStartNorm == nil {
                    dragStartNorm = normPt
                    shapeStartCanvas = canvasPt
                    controller.s2LiveMarqueeStartNorm = normPt
                }
                dragCurrentNorm = normPt
                shapeEndCanvas = canvasPt
                controller.s2LiveMarqueeCurrentNorm = normPt
                return
            }
            break

        default:
            break
        }

        if let activeLayer = controller.selectedCelLayer, !activeLayer.visible {
            statusLine = "Layer '\(activeLayer.name)' is hidden."
            return
        }

        // Rope Stabilizer smoothing in canvas coordinates
        let rope = CGFloat(controller.s2StabilizerPx)
        let targetPt: CGPoint
        if let prevStab = stabilizedPoint, rope > 0.5 {
            let dx = canvasPt.x - prevStab.x
            let dy = canvasPt.y - prevStab.y
            let dist = hypot(dx, dy)
            if dist > rope {
                let pull = (dist - rope) / dist
                targetPt = CGPoint(x: prevStab.x + dx * pull, y: prevStab.y + dy * pull)
            } else {
                targetPt = prevStab
            }
        } else {
            targetPt = canvasPt
        }
        stabilizedPoint = targetPt

        if lastDragCanvasPoint == nil {
            controller.beginRasterUndoCheckpoint()
            strokeAnchorCanvasPoint = targetPt
            strokePointCount = 0
        }
        let fromPt = lastDragCanvasPoint ?? targetPt
        let anchorPt = strokeAnchorCanvasPoint ?? targetPt
        strokePointCount += 1

        // Force Fade taper on entry stroke
        var effectiveRadius = Float(max(0.75, controller.s2BrushSize * 0.5))
        if controller.s2ForceFade && strokePointCount <= 4 {
            let t = Float(strokePointCount) / 5.0
            effectiveRadius = max(0.75, effectiveRadius * (0.35 + 0.65 * t))
        }

        _ = controller.applyRulerAwareRasterSegment(
            from: fromPt,
            to: targetPt,
            anchor: anchorPt,
            radiusPx: effectiveRadius,
            hardness: activePresetHardness,
            opacity: Float(controller.s2BrushOpacity)
        )
        lastDragCanvasPoint = targetPt
        controller.refreshCompositeImage()
    }

    private func handleCanvasDragEnded(at viewPoint: CGPoint, canvasViewSize: CGSize) {
        if controller.s2Tool == .handPan {
            panDragPrevViewPt = nil
            statusLine = "画布已移动 (\(Int(controller.s2PanOffset.width)), \(Int(controller.s2PanOffset.height)))"
            return
        }

        let mapped = mapViewPointToCanvas(viewPoint, viewSize: canvasViewSize)
        let canvasPt = mapped.canvas
        let normPt = mapped.norm

        switch controller.s2Tool {
        case .eyedropper:
            if let picked = controller.sampleEyedropper(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y)) {
                if controller.s2EyedropperAutoSwitchToBrush {
                    controller.s2Tool = .brush
                    statusLine = "已提取颜色 \(picked.hexString) → 自动切回画笔"
                } else {
                    statusLine = "已提取颜色 \(picked.hexString)"
                }
            }
            eyedropperLoupePos = nil
            controller.s2EyedropperLoupeNorm = nil
            return

        case .bucket:
            let filled = controller.applyBucketFill(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y))
            statusLine = "Close-Gap Bucket filled \(filled) px."
            return

        case .magicWand:
            let count = controller.applyMagicWandSelection(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y))
            statusLine = "魔棒已选中 \(count) px · 请在上方选区栏进行填充、清除或扩缩"
            return

        case .textBubble:
            controller.addSpeechBubble(normX: Double(normPt.x), normY: Double(normPt.y))
            statusLine = controller.lastStatusBanner
            return

        case .panelKnife:
            if let s = shapeStartCanvas, let e = shapeEndCanvas {
                let count = controller.slicePanelFrame(from: s, to: e, gutterPx: Float(controller.s2PanelGutterPx))
                statusLine = "Panel Knife sliced frame (\(count) panels)."
            }
            dragStartNorm = nil
            dragCurrentNorm = nil
            shapeStartCanvas = nil
            shapeEndCanvas = nil
            controller.s2LiveMarqueeStartNorm = nil
            controller.s2LiveMarqueeCurrentNorm = nil
            return

        case .rectSelect:
            if let s = dragStartNorm, let e = dragCurrentNorm {
                let normRect = CGRect(
                    x: min(s.x, e.x),
                    y: min(s.y, e.y),
                    width: max(0.01, abs(e.x - s.x)),
                    height: max(0.01, abs(e.y - s.y))
                )
                let canvasRect = CGRect(
                    x: normRect.minX * CGFloat(controller.s2CanvasPixelWidth),
                    y: normRect.minY * CGFloat(controller.s2CanvasPixelHeight),
                    width: max(4.0, normRect.width * CGFloat(controller.s2CanvasPixelWidth)),
                    height: max(4.0, normRect.height * CGFloat(controller.s2CanvasPixelHeight))
                )
                let count = controller.setMarqueeSelection(canvasRect: canvasRect, normRect: normRect)
                statusLine = "选区已建立 (\(count) px) · 请使用上方选区栏进行填色、清除或调整"
            }
            dragStartNorm = nil
            dragCurrentNorm = nil
            controller.s2LiveMarqueeStartNorm = nil
            controller.s2LiveMarqueeCurrentNorm = nil
            return

        case .lasso:
            if activeLassoCanvas.count >= 3 {
                let count = controller.setLassoSelection(
                    canvasPoints: activeLassoCanvas,
                    normPoints: activeLassoNorm
                )
                statusLine = "套索已选中 \(count) px · 请在上方选区栏进行填色、清除或扩缩调整"
            }
            activeLassoCanvas.removeAll()
            activeLassoNorm.removeAll()
            controller.s2LiveLassoNorm.removeAll()
            return

        case .brush:
            if controller.s2ShapeAssist != .freehand, let s = shapeStartCanvas, let e = shapeEndCanvas {
                _ = controller.drawRasterShape(
                    kind: controller.s2ShapeAssist,
                    from: s,
                    to: e,
                    radiusPx: Float(max(1.0, controller.s2BrushSize * 0.5)),
                    hardness: activePresetHardness,
                    opacity: Float(controller.s2BrushOpacity)
                )
                statusLine = controller.lastStatusBanner
                dragStartNorm = nil
                dragCurrentNorm = nil
                shapeStartCanvas = nil
                shapeEndCanvas = nil
                controller.s2LiveMarqueeStartNorm = nil
                controller.s2LiveMarqueeCurrentNorm = nil
                return
            }

        default:
            break
        }

        if lastDragCanvasPoint != nil {
            lastDragCanvasPoint = nil
            strokeAnchorCanvasPoint = nil
            stabilizedPoint = nil
            strokePointCount = 0
            controller.refreshCompositeImage()
            controller.markDirtyAndScheduleSave()
            statusLine = "Committed \(controller.s2Tool.displayName) (\(controller.s2AllocatedTiles) tiles)."
        }
    }

    private func renderLiveShapeOrKnifePreview(in context: inout GraphicsContext, size: CGSize) {
        let sOpt = dragStartNorm ?? controller.s2LiveMarqueeStartNorm
        let eOpt = dragCurrentNorm ?? controller.s2LiveMarqueeCurrentNorm
        guard let s = sOpt, let e = eOpt else { return }
        let p0 = CGPoint(x: s.x * size.width, y: s.y * size.height)
        let p1 = CGPoint(x: e.x * size.width, y: e.y * size.height)

        if controller.s2Tool == .panelKnife {
            var line = Path()
            line.move(to: p0)
            line.addLine(to: p1)
            context.stroke(line, with: .color(SuiteColorTokens.mangaAccent), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
            return
        }

        if controller.s2Tool == .brush && controller.s2ShapeAssist != .freehand {
            let rect = CGRect(x: min(p0.x, p1.x), y: min(p0.y, p1.y), width: abs(p1.x - p0.x), height: abs(p1.y - p0.y))
            var path = Path()
            switch controller.s2ShapeAssist {
            case .line:
                path.move(to: p0)
                path.addLine(to: p1)
            case .rectangle:
                path.addRect(rect)
            case .ellipse:
                path.addEllipse(in: rect)
            case .freehand:
                break
            }
            context.stroke(path, with: .color(controller.s2ActiveColor.swiftUIColor), lineWidth: max(1.5, CGFloat(controller.s2BrushSize * 0.5)))
        }
    }

    private func renderSelectionOverlay(in context: inout GraphicsContext, size: CGSize) {
        let dashStyle = StrokeStyle(lineWidth: 2.0, dash: [6, 4])

        // Live marquee drag preview (works on both iPadOS UIKit touch & macOS drag)
        let sOpt = dragStartNorm ?? controller.s2LiveMarqueeStartNorm
        let eOpt = dragCurrentNorm ?? controller.s2LiveMarqueeCurrentNorm
        if controller.s2Tool == .rectSelect, let s = sOpt, let e = eOpt {
            let rect = CGRect(
                x: min(s.x, e.x) * size.width,
                y: min(s.y, e.y) * size.height,
                width: abs(e.x - s.x) * size.width,
                height: abs(e.y - s.y) * size.height
            )
            let p = Path(rect)
            context.fill(p, with: .color(SuiteColorTokens.hubAccent.opacity(0.14)))
            context.stroke(p, with: .color(.black), lineWidth: 2.5)
            context.stroke(p, with: .color(.white), style: dashStyle)
            return
        }

        // Live lasso drag preview (works on both iPadOS UIKit touch & macOS drag)
        let liveLasso = !controller.s2LiveLassoNorm.isEmpty ? controller.s2LiveLassoNorm : activeLassoNorm
        if liveLasso.count >= 2 {
            var p = Path()
            p.move(to: CGPoint(x: liveLasso[0].x * size.width, y: liveLasso[0].y * size.height))
            for pt in liveLasso.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
            }
            context.fill(p, with: .color(SuiteColorTokens.hubAccent.opacity(0.14)))
            context.stroke(p, with: .color(.black), lineWidth: 2.5)
            context.stroke(p, with: .color(.white), style: dashStyle)
            return
        }

        // Committed marching-ants selection with subtle cyan highlight tint
        if let rectNorm = controller.s2SelectionRectNorm {
            let rect = CGRect(
                x: rectNorm.minX * size.width,
                y: rectNorm.minY * size.height,
                width: rectNorm.width * size.width,
                height: rectNorm.height * size.height
            )
            let p = Path(rect)
            context.fill(p, with: .color(SuiteColorTokens.hubAccent.opacity(0.10)))
            context.stroke(p, with: .color(.black.opacity(0.85)), lineWidth: 2.5)
            context.stroke(p, with: .color(SuiteColorTokens.hubAccent), style: dashStyle)
        } else if controller.s2SelectionLassoNorm.count >= 3 {
            var p = Path()
            let pts = controller.s2SelectionLassoNorm
            p.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
            for pt in pts.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
            }
            p.closeSubpath()
            context.fill(p, with: .color(SuiteColorTokens.hubAccent.opacity(0.10)))
            context.stroke(p, with: .color(.black.opacity(0.85)), lineWidth: 2.5)
            context.stroke(p, with: .color(SuiteColorTokens.hubAccent), style: dashStyle)
        }
    }

    private func renderActiveRulerGuide(in context: inout GraphicsContext, size: CGSize) {
        guard controller.s2RulerMode != .off else { return }
        var guide = Path()
        switch controller.s2RulerMode {
        case .symmetry:
            guide.move(to: CGPoint(x: size.width * 0.5, y: 0))
            guide.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
        case .parallel:
            for step in stride(from: CGFloat(40), to: size.height, by: 60) {
                guide.move(to: CGPoint(x: 0, y: step))
                guide.addLine(to: CGPoint(x: size.width, y: step))
            }
        case .perspective2Pt:
            let horizon = size.height * 0.45
            guide.move(to: CGPoint(x: 0, y: horizon))
            guide.addLine(to: CGPoint(x: size.width, y: horizon))
            for y in [CGFloat(0), size.height * 0.2, size.height * 0.8, size.height] {
                guide.move(to: CGPoint(x: 0, y: horizon))
                guide.addLine(to: CGPoint(x: size.width, y: y))
                guide.move(to: CGPoint(x: size.width, y: horizon))
                guide.addLine(to: CGPoint(x: 0, y: y))
            }
        case .focusLines:
            let cx = size.width * 0.5
            let cy = size.height * 0.5
            let r = max(size.width, size.height)
            for deg in stride(from: 0.0, to: 360.0, by: 22.5) {
                let rad = deg * .pi / 180.0
                guide.move(to: CGPoint(x: cx, y: cy))
                guide.addLine(to: CGPoint(x: cx + cos(rad) * r, y: cy + sin(rad) * r))
            }
        case .off:
            break
        }
        context.stroke(
            guide,
            with: .color(SuiteColorTokens.hubAccent.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
        )
    }

    // MARK: - Phase 3: Speech Bubble Overlay, Floating Reference Window & FX Filter Sheet

    private func speechBubbleView(bubble: Binding<PersistedSpeechBubble>, canvasSize: CGSize) -> some View {
        VStack(spacing: 4) {
            if controller.s2Tool == .textBubble {
                HStack(spacing: 4) {
                    Button(bubble.wrappedValue.isVertical ? "縦" : "H") {
                        bubble.wrappedValue.isVertical.toggle()
                        controller.markDirtyAndScheduleSave()
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(SuiteColorTokens.mangaAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)

                    Button {
                        controller.removeSpeechBubble(id: bubble.wrappedValue.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Group {
                if controller.s2Tool == .textBubble {
                    TextField("Dialogue...", text: bubble.text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 70, maxWidth: 140)
                } else {
                    Text(bubble.wrappedValue.text)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .overlay(
                Capsule()
                    .strokeBorder(Color.black, lineWidth: 2)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .position(
            x: CGFloat(bubble.wrappedValue.normX) * canvasSize.width,
            y: CGFloat(bubble.wrappedValue.normY) * canvasSize.height
        )
    }

    private var floatingReferenceWindow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.caption2)
                    .foregroundStyle(SuiteColorTokens.hubAccent)
                Text(controller.s2ReferenceImage != nil ? "参考图片" : "Reference")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                #if canImport(PhotosUI)
                PhotosPicker(selection: $photoRefPickerItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.caption2.bold())
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                }
                .buttonStyle(.plain)
                .help("从相册载入参考图")
                #endif
                #if canImport(CoreGraphics)
                if controller.s2ReferenceImage != nil {
                    Button {
                        controller.clearReferenceImage()
                        statusLine = controller.lastStatusBanner
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .help("清除参考图，恢复画布总览")
                }
                #endif
                Button {
                    controller.s2ShowReferenceWindow = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }

            #if canImport(CoreGraphics)
            if let cg = controller.s2ReferenceImage ?? controller.s2CompositeImage {
                Image(decorative: cg, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.2)))
            }
            #endif

            // Quick Eyedropper Character Reference Swatches
            HStack(spacing: 5) {
                ForEach(controller.s2RecentColors.prefix(6), id: \.hexString) { swatch in
                    Button {
                        controller.setActiveColor(swatch)
                        statusLine = "Picked reference color \(swatch.hexString)"
                    } label: {
                        Circle()
                            .fill(swatch.swiftUIColor)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(SuiteColorTokens.mangaPanel.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SuiteColorTokens.hubAccent.opacity(0.65), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
        .gesture(
            DragGesture()
                .onChanged { val in
                    refWindowOffset = CGSize(
                        width: refWindowOffset.width + val.translation.width * 0.25,
                        height: refWindowOffset.height + val.translation.height * 0.25
                    )
                }
        )
    }

    // MARK: - Multi-Canvas Gallery, New Canvas Presets & Photo Import Sheet

    #if canImport(CoreGraphics) && canImport(ImageIO)
    private func loadGalleryThumbCGImage(path: String?) -> CGImage? {
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
    #endif

    private var canvasGallerySheetView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("多画布画廊 · 新建画布与导入图片", systemImage: "square.grid.2x2.fill")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    controller.s2ShowCanvasGallery = false
                }
                .buttonStyle(.borderedProminent)
                .tint(SuiteColorTokens.mangaAccent)
            }

            // Quick Photo Import Bar (Direct PhotosPicker — works natively on iPad Pro & Mac)
            HStack(spacing: 10) {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $photoLayerPickerItem, matching: .images) {
                    Label("导入相册图片为新图层", systemImage: "photo.badge.plus")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.hubAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $photoRefPickerItem, matching: .images) {
                    Label("导入相册到参考浮窗", systemImage: "photo.on.rectangle.angled")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(SuiteColorTokens.novelAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                #endif

                Spacer()
                Text("当前画布: \(controller.s2CanvasPixelWidth) × \(controller.s2CanvasPixelHeight)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Create New Canvas with Pro Manga / 4K / Webtoon Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("新建画布预设 (B4 / A4 / 4K / 条漫 / 自定义)")
                    .font(.subheadline.bold())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CanvasSizePresetOption.allPresets) { opt in
                            let selected = selectedSizePresetId == opt.id
                            Button {
                                selectedSizePresetId = opt.id
                                newCanvasWidthText = "\(opt.width)"
                                newCanvasHeightText = "\(opt.height)"
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(opt.title)
                                        .font(.caption.bold())
                                    Text(opt.subtitle)
                                        .font(.caption2)
                                        .opacity(0.8)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selected ? SuiteColorTokens.mangaAccent : Color.secondary.opacity(0.14))
                                .foregroundStyle(selected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("画布名称", text: $newCanvasTitle)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    HStack(spacing: 4) {
                        Text("宽")
                            .font(.caption)
                        TextField("宽", text: $newCanvasWidthText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                        Text("× 高")
                            .font(.caption)
                        TextField("高", text: $newCanvasHeightText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                    }
                    Button {
                        let w = Int(newCanvasWidthText) ?? 1200
                        let h = Int(newCanvasHeightText) ?? 1698
                        let preset = CanvasSizePresetOption.allPresets.first(where: { $0.id == selectedSizePresetId })?.preset ?? .b4PrintManga600Dpi
                        if controller.createNewCanvasProject(title: newCanvasTitle, width: w, height: h, preset: preset) {
                            refreshCanvasDimsLabel()
                            statusLine = controller.lastStatusBanner
                            controller.s2ShowCanvasGallery = false
                        }
                    } label: {
                        Label("新建并打开", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SuiteColorTokens.mangaAccent)
                }
            }

            Divider()

            // Existing Multi-Canvas Gallery Grid
            Text("我的画布作品 (\(controller.s2GalleryItems.count))")
                .font(.subheadline.bold())

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 12)], spacing: 12) {
                    ForEach(controller.s2GalleryItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(height: 112)
                                    .overlay {
                                        #if canImport(CoreGraphics) && canImport(ImageIO)
                                        if let cg = loadGalleryThumbCGImage(path: item.thumbnailPath) {
                                            Image(decorative: cg, scale: 1.0)
                                                .resizable()
                                                .scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .padding(4)
                                        } else {
                                            Image(systemName: "paintbrush.pointed")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                        #else
                                        Image(systemName: "paintbrush.pointed")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                        #endif
                                    }

                                if item.isActive {
                                    Text("当前")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(SuiteColorTokens.mangaAccent)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                        .padding(6)
                                }
                            }

                            Text(item.title)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text("\(item.width) × \(item.height) · \(item.layerCount) 图层")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                Button(item.isActive ? "继续画" : "打开") {
                                    if !item.isActive {
                                        controller.switchToCanvasProject(dir: item.id)
                                        refreshCanvasDimsLabel()
                                        statusLine = controller.lastStatusBanner
                                    }
                                    controller.s2ShowCanvasGallery = false
                                }
                                .font(.caption2.bold())
                                .buttonStyle(.borderedProminent)
                                .tint(item.isActive ? SuiteColorTokens.novelAccent : SuiteColorTokens.hubAccent)

                                Button {
                                    _ = controller.duplicateCanvasProject(dir: item.id)
                                    statusLine = controller.lastStatusBanner
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .help("复制作品")

                                if controller.s2GalleryItems.count > 1 {
                                    Button(role: .destructive) {
                                        _ = controller.deleteCanvasProject(dir: item.id)
                                        statusLine = controller.lastStatusBanner
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.bordered)
                                    .help("删除作品")
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(item.isActive ? SuiteColorTokens.mangaAccent : Color.secondary.opacity(0.25), lineWidth: item.isActive ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(18)
        .frame(minWidth: 560, minHeight: 520)
    }

    private func fxFilterSheetView(fx: S2FilterActionKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(fx.displayName, systemImage: "wand.and.rays")
                    .font(.headline)
                Spacer()
                Text("1-Step Undo Protected")
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SuiteColorTokens.novelAccent.opacity(0.18))
                    .foregroundStyle(SuiteColorTokens.novelAccent)
                    .clipShape(Capsule())
            }

            Divider()

            switch fx {
            case .gaussianBlur:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Blur Radius: \(String(format: "%.1f", fxBlurRadius)) px")
                        .font(.caption.monospaced())
                    Slider(value: $fxBlurRadius, in: 0.5...20.0)
                }

            case .hsbAdjust:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hue: \(Int(fxHueDeg))°").font(.caption.monospaced())
                    Slider(value: $fxHueDeg, in: -180...180)
                    Text("Saturation: \(Int(fxSatDelta * 100))%").font(.caption.monospaced())
                    Slider(value: $fxSatDelta, in: -1.0...1.0)
                    Text("Brightness: \(Int(fxBrightDelta * 100))%").font(.caption.monospaced())
                    Slider(value: $fxBrightDelta, in: -1.0...1.0)
                }

            case .brightnessContrast:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brightness: \(Int(fxBrightDelta * 100))%").font(.caption.monospaced())
                    Slider(value: $fxBrightDelta, in: -1.0...1.0)
                    Text("Contrast: \(Int(fxContrast * 100))%").font(.caption.monospaced())
                    Slider(value: $fxContrast, in: -1.0...1.0)
                }

            case .extractLineDrawing:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Black Ink Threshold: \(Int(fxExtractBlack * 100))%").font(.caption.monospaced())
                    Slider(value: $fxExtractBlack, in: 0.05...0.70)
                    Text("White Paper Cutoff: \(Int(fxExtractWhite * 100))%").font(.caption.monospaced())
                    Slider(value: $fxExtractWhite, in: 0.40...0.98)
                }

            case .outerStroke:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stroke Width: \(Int(fxStrokeWidth)) px (uses Active Color \(controller.s2ActiveColor.hexString))")
                        .font(.caption.monospaced())
                    Slider(value: $fxStrokeWidth, in: 1...20)
                }

            case .dropShadow:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Offset X: \(Int(fxShadowDx)) px").font(.caption.monospaced())
                    Slider(value: $fxShadowDx, in: -30...30)
                    Text("Offset Y: \(Int(fxShadowDy)) px").font(.caption.monospaced())
                    Slider(value: $fxShadowDy, in: -30...30)
                    Text("Shadow Blur: \(String(format: "%.1f", fxShadowBlur)) px").font(.caption.monospaced())
                    Slider(value: $fxShadowBlur, in: 0.5...16.0)
                }
            }

            Divider()

            HStack {
                Button("Cancel") {
                    controller.s2PendingFilter = nil
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply FX Filter") {
                    switch fx {
                    case .gaussianBlur:
                        _ = controller.applyFilterGaussianBlur(radiusPx: Float(fxBlurRadius))
                    case .hsbAdjust:
                        _ = controller.applyFilterHsb(
                            hueDeg: Float(fxHueDeg),
                            satDelta: Float(fxSatDelta),
                            brightDelta: Float(fxBrightDelta)
                        )
                    case .brightnessContrast:
                        _ = controller.applyFilterBrightnessContrast(
                            brightness: Float(fxBrightDelta),
                            contrast: Float(fxContrast)
                        )
                    case .extractLineDrawing:
                        _ = controller.applyFilterExtractLineDrawing(
                            blackThreshold: Float(fxExtractBlack),
                            whiteThreshold: Float(fxExtractWhite)
                        )
                    case .outerStroke:
                        _ = controller.applyFilterOuterStroke(
                            widthPx: UInt32(max(1, Int(fxStrokeWidth.rounded()))),
                            color: controller.s2ActiveColor
                        )
                    case .dropShadow:
                        _ = controller.applyFilterDropShadow(
                            dx: Int32(fxShadowDx.rounded()),
                            dy: Int32(fxShadowDy.rounded()),
                            blurPx: Float(fxShadowBlur),
                            color: PersistedRGBA(r: 0, g: 0, b: 0, a: 160)
                        )
                    }
                    statusLine = controller.lastStatusBanner
                    controller.s2PendingFilter = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(SuiteColorTokens.mangaAccent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
#endif
