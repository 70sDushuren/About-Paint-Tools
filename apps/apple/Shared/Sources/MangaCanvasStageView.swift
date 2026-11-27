import Foundation

#if canImport(SwiftUI)
import SwiftUI
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
/// - Live interactive Close-Gap Bucket Fill, Eyedropper loupe, Marquee / Lasso / Magic Wand selections.
public struct MangaCanvasStageView: View {
    @ObservedObject public var controller: StudioWorkspaceController
    public let layout: WorkspaceLayoutHintKind

    @State private var lastDragCanvasPoint: CGPoint?
    @State private var stabilizedPoint: CGPoint?
    @State private var strokePointCount: Int = 0
    @State private var dragStartNorm: CGPoint?
    @State private var dragCurrentNorm: CGPoint?
    @State private var activeLassoNorm: [CGPoint] = []
    @State private var activeLassoCanvas: [CGPoint] = []
    @State private var eyedropperLoupePos: CGPoint?
    @State private var pinchBaseZoom: Double?
    @State private var canvasDimensions: String = "800 × 1132 (B4 Live RGBA8)"
    @State private var statusLine: String = "Ready"

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
                contextualToolPropertyBar
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
        .onAppear {
            controller.ensureRustCanvasAndLayersInitialized()
            refreshCanvasDimsLabel()
        }
    }

    // MARK: - Left 56px ibisPaint-Aligned Tool Rail

    private var ibisToolRail: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(S2DrawingToolKind.allCases) { tool in
                    let selected = controller.s2Tool == tool
                    Button {
                        controller.selectTool(tool)
                    } label: {
                        Image(systemName: tool.systemSymbol)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 36)
                            .background(selected ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.05))
                            .foregroundStyle(selected ? .white : Color.white.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(tool.displayName)
                }

                Divider().background(SuiteColorTokens.mangaBorder).padding(.horizontal, 8)

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
            ColorPicker("", selection: activeColorBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30, height: 30)
                .help("Active Foreground Color (\(controller.s2ActiveColor.hexString))")

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

    // MARK: - Zero-Overlap Contextual Top Tool Property Bar (1:1 Synced with Menu Bar)

    private var contextualToolPropertyBar: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Label(controller.s2Tool.displayName, systemImage: controller.s2Tool.systemSymbol)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(SuiteColorTokens.mangaAccent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)

                    if controller.s2Tool.usesBrushDynamics {
                        Toggle("Force Fade", isOn: $controller.s2ForceFade)
                            .toggleStyle(.button)
                            .font(.caption2.bold())
                            .tint(SuiteColorTokens.mangaAccent)
                            .fixedSize(horizontal: true, vertical: false)

                        HStack(spacing: 5) {
                            Text("Rope \(Int(controller.s2StabilizerPx))px")
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.white.opacity(0.82))
                                .fixedSize(horizontal: true, vertical: false)
                            Slider(value: $controller.s2StabilizerPx, in: 0...24)
                                .frame(width: 76)
                                .tint(SuiteColorTokens.mangaAccent)
                        }
                    }

                    if controller.s2Tool == .bucket {
                        Menu("Gap: \(controller.s2BucketCloseGapPx)px") {
                            ForEach([0, 1, 2, 3, 5, 8], id: \.self) { px in
                                Button("\(px)px") { controller.s2BucketCloseGapPx = px }
                            }
                        }
                        .font(.caption2.bold())
                        .fixedSize(horizontal: true, vertical: false)

                        Menu("Expand: \(controller.s2BucketExpandPx)px") {
                            ForEach([0, 1, 2, 3], id: \.self) { px in
                                Button("+\(px)px") { controller.s2BucketExpandPx = px }
                            }
                        }
                        .font(.caption2.bold())
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    Menu("Ruler: \(controller.s2RulerMode.displayName)") {
                        ForEach(RulerModeKind.allCases) { mode in
                            Button(mode.displayName) { controller.s2RulerMode = mode }
                        }
                    }
                    .font(.caption2.bold())
                    .fixedSize(horizontal: true, vertical: false)

                    Menu("Shape: \(controller.s2ShapeAssist.displayName)") {
                        ForEach(S2ShapeAssistKind.allCases) { shape in
                            Button(shape.displayName) { controller.s2ShapeAssist = shape }
                        }
                    }
                    .font(.caption2.bold())
                    .fixedSize(horizontal: true, vertical: false)

                    if let activeLayer = controller.selectedCelLayer {
                        Text("Layer: \(activeLayer.name) [\(activeLayer.blendMode.displayName)]")
                            .font(.caption2.monospaced())
                            .foregroundStyle(activeLayer.blueSketchTint ? Color(red: 0.45, green: 0.72, blue: 1.0) : Color.white.opacity(0.75))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .layoutPriority(1)

            // Right fixed quick actions (guaranteed non-overlapping)
            HStack(spacing: 8) {
                Button {
                    controller.s2MirrorHorizontal.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.caption)
                        .foregroundStyle(controller.s2MirrorHorizontal ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Horizontal Mirror Preview (H)")

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
                .help("Reset Viewport (⌘0)")

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

    // MARK: - Real Rust RGBA8 Composited Canvas Viewport (Zero Overlapping Debug Overlays)

    private var canvasAspectRatio: CGFloat {
        let w = CGFloat(max(1, controller.s2CanvasPixelWidth))
        let h = CGFloat(max(1, controller.s2CanvasPixelHeight))
        return w / h
    }

    private var canvasViewport: some View {
        GeometryReader { outerGeo in
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

                    // Vector overlay strictly for active ruler guides, marching-ants selection & eyedropper loupe
                    Canvas { context, size in
                        renderActiveRulerGuide(in: &context, size: size)
                        renderSelectionOverlay(in: &context, size: size)
                    }
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    if let loupePos = eyedropperLoupePos, let preview = controller.s2EyedropperPreview {
                        Circle()
                            .fill(preview.swiftUIColor)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                            .shadow(color: .black.opacity(0.5), radius: 6)
                            .position(x: loupePos.x, y: max(28, loupePos.y - 36))
                            .allowsHitTesting(false)
                    }
                }
                .aspectRatio(canvasAspectRatio, contentMode: .fit)
                .overlay {
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
        }
        .clipped()
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
        let mapped = mapViewPointToCanvas(viewPoint, viewSize: canvasViewSize)
        let canvasPt = mapped.canvas
        let normPt = mapped.norm

        switch controller.s2Tool {
        case .eyedropper:
            eyedropperLoupePos = viewPoint
            if let picked = controller.sampleEyedropper(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y)) {
                statusLine = "Eyedropper: \(picked.hexString)"
            }
            return

        case .bucket:
            // Trigger on drag ended so single click fills once cleanly
            return

        case .magicWand:
            return

        case .rectSelect:
            if dragStartNorm == nil {
                dragStartNorm = normPt
            }
            dragCurrentNorm = normPt
            return

        case .lasso:
            activeLassoNorm.append(normPt)
            activeLassoCanvas.append(canvasPt)
            return

        case .brush, .eraser, .smudge, .blur:
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
            strokePointCount = 0
        }
        let fromPt = lastDragCanvasPoint ?? targetPt
        strokePointCount += 1

        // Force Fade taper on entry stroke
        var effectiveRadius = Float(max(0.75, controller.s2BrushSize * 0.5))
        if controller.s2ForceFade && strokePointCount <= 4 {
            let t = Float(strokePointCount) / 5.0
            effectiveRadius = max(0.75, effectiveRadius * (0.35 + 0.65 * t))
        }

        _ = controller.applyRasterSegment(
            from: fromPt,
            to: targetPt,
            radiusPx: effectiveRadius,
            hardness: activePresetHardness,
            opacity: Float(controller.s2BrushOpacity)
        )
        lastDragCanvasPoint = targetPt
        controller.refreshCompositeImage()
    }

    private func handleCanvasDragEnded(at viewPoint: CGPoint, canvasViewSize: CGSize) {
        let mapped = mapViewPointToCanvas(viewPoint, viewSize: canvasViewSize)
        let canvasPt = mapped.canvas

        switch controller.s2Tool {
        case .eyedropper:
            eyedropperLoupePos = nil
            return

        case .bucket:
            let filled = controller.applyBucketFill(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y))
            statusLine = "Close-Gap Bucket filled \(filled) px."
            return

        case .magicWand:
            let count = controller.applyMagicWandSelection(canvasX: Int(canvasPt.x), canvasY: Int(canvasPt.y))
            statusLine = "Magic Wand selected \(count) px."
            return

        case .rectSelect:
            if let s = dragStartNorm, let e = dragCurrentNorm {
                let normRect = CGRect(
                    x: min(s.x, e.x),
                    y: min(s.y, e.y),
                    width: abs(e.x - s.x),
                    height: abs(e.y - s.y)
                )
                let canvasRect = CGRect(
                    x: normRect.minX * CGFloat(controller.s2CanvasPixelWidth),
                    y: normRect.minY * CGFloat(controller.s2CanvasPixelHeight),
                    width: normRect.width * CGFloat(controller.s2CanvasPixelWidth),
                    height: normRect.height * CGFloat(controller.s2CanvasPixelHeight)
                )
                let count = controller.setMarqueeSelection(canvasRect: canvasRect, normRect: normRect)
                statusLine = "Marquee selected \(count) px."
            }
            dragStartNorm = nil
            dragCurrentNorm = nil
            return

        case .lasso:
            if activeLassoCanvas.count >= 3 {
                let count = controller.setLassoSelection(
                    canvasPoints: activeLassoCanvas,
                    normPoints: activeLassoNorm
                )
                statusLine = "Lasso selected \(count) px."
            }
            activeLassoCanvas.removeAll()
            activeLassoNorm.removeAll()
            return

        default:
            break
        }

        if lastDragCanvasPoint != nil {
            lastDragCanvasPoint = nil
            stabilizedPoint = nil
            strokePointCount = 0
            controller.refreshCompositeImage()
            controller.markDirtyAndScheduleSave()
            statusLine = "Committed \(controller.s2Tool.displayName) (\(controller.s2AllocatedTiles) tiles)."
        }
    }

    private func renderSelectionOverlay(in context: inout GraphicsContext, size: CGSize) {
        let dashStyle = StrokeStyle(lineWidth: 1.5, dash: [5, 4])

        // Live marquee drag preview
        if let s = dragStartNorm, let e = dragCurrentNorm {
            let rect = CGRect(
                x: min(s.x, e.x) * size.width,
                y: min(s.y, e.y) * size.height,
                width: abs(e.x - s.x) * size.width,
                height: abs(e.y - s.y) * size.height
            )
            let p = Path(rect)
            context.stroke(p, with: .color(.black), lineWidth: 2.0)
            context.stroke(p, with: .color(.white), style: dashStyle)
            return
        }

        // Live lasso drag preview
        if activeLassoNorm.count >= 2 {
            var p = Path()
            p.move(to: CGPoint(x: activeLassoNorm[0].x * size.width, y: activeLassoNorm[0].y * size.height))
            for pt in activeLassoNorm.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
            }
            context.stroke(p, with: .color(.black), lineWidth: 2.0)
            context.stroke(p, with: .color(.white), style: dashStyle)
            return
        }

        // Committed marching-ants selection
        if let rectNorm = controller.s2SelectionRectNorm {
            let rect = CGRect(
                x: rectNorm.minX * size.width,
                y: rectNorm.minY * size.height,
                width: rectNorm.width * size.width,
                height: rectNorm.height * size.height
            )
            let p = Path(rect)
            context.stroke(p, with: .color(.black.opacity(0.85)), lineWidth: 2.0)
            context.stroke(p, with: .color(.white), style: dashStyle)
        } else if controller.s2SelectionLassoNorm.count >= 3 {
            var p = Path()
            let pts = controller.s2SelectionLassoNorm
            p.move(to: CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height))
            for pt in pts.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x * size.width, y: pt.y * size.height))
            }
            p.closeSubpath()
            context.stroke(p, with: .color(.black.opacity(0.85)), lineWidth: 2.0)
            context.stroke(p, with: .color(.white), style: dashStyle)
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
}
#endif
