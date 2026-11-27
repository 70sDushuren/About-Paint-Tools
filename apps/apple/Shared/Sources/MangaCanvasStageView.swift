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
    public let isEraser: Bool

    public init(
        id: UInt32,
        name: String,
        trackBadge: String,
        defaultSize: Double = 6.0,
        baseOpacity: Double = 1.0,
        isEraser: Bool = false
    ) {
        self.id = id
        self.name = name
        self.trackBadge = trackBadge
        self.defaultSize = defaultSize
        self.baseOpacity = baseOpacity
        self.isEraser = isEraser
    }
}

extension LayerBlendMode {
    /// Maps all 13 Rust `BlendMode` values to SwiftUI `GraphicsContext.BlendMode`.
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
        }
    }
}

/// `S2 v1.0.0-rc2` — `雕龙 / DracoNib` ibisPaint-aligned Studio Stage:
/// - Bound 100% to `StudioWorkspaceController` (zero state loss on tool switch or app restart).
/// - Zero-overlap responsive contextual top property bar synced 1:1 with macOS Menu Bar.
/// - Clean left ibisPaint-style Tool Rail + Size/Opacity/Color side caliper (no overlapping canvas text!).
public struct MangaCanvasStageView: View {
    @ObservedObject public var controller: StudioWorkspaceController
    public let layout: WorkspaceLayoutHintKind

    @State private var activeStroke: PersistedCanvasStroke?
    @State private var canvasDimensions: String = "6071 × 8598 (B4 600DPI)"
    @State private var statusLine: String = "Ready"
    @State private var showColorPopover: Bool = false

    private let starterPresets: [BrushPresetDescriptor] = [
        BrushPresetDescriptor(id: 0, name: "G-Pen (Hard)", trackBadge: "Ink", defaultSize: 6.0),
        BrushPresetDescriptor(id: 1, name: "Maru-Pen (Fine)", trackBadge: "Fine", defaultSize: 3.5),
        BrushPresetDescriptor(id: 2, name: "Dip Pen (Soft)", trackBadge: "Ink", defaultSize: 7.5),
        BrushPresetDescriptor(id: 3, name: "Blue Pencil 2B", trackBadge: "Sketch", defaultSize: 5.0, baseOpacity: 0.72),
        BrushPresetDescriptor(id: 4, name: "Flat Cel Marker", trackBadge: "Cel", defaultSize: 18.0),
        BrushPresetDescriptor(id: 5, name: "Soft Airbrush", trackBadge: "Air", defaultSize: 28.0, baseOpacity: 0.35),
        BrushPresetDescriptor(id: 6, name: "Watercolor Blend", trackBadge: "Wet", defaultSize: 20.0, baseOpacity: 0.58),
        BrushPresetDescriptor(id: 7, name: "Vector / Pixel Eraser", trackBadge: "Clean", defaultSize: 16.0, isEraser: true),
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

    // MARK: - Clean Drawable Canvas Viewport (Zero Overlapping Debug Overlays)

    private var canvasViewport: some View {
        ZStack {
            SuiteColorTokens.mangaCharcoal

            ZStack {
                canvasBackdropView

                Canvas { context, size in
                    renderAllCelLayers(in: &context)
                    renderActiveRulerGuide(in: &context, size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleCanvasDragChanged(at: value.location)
                        }
                        .onEnded { _ in
                            handleCanvasDragEnded()
                        }
                )
            }
            .scaleEffect(
                x: controller.s2ViewportZoom * (controller.s2MirrorHorizontal ? -1.0 : 1.0),
                y: controller.s2ViewportZoom
            )
            .offset(controller.s2PanOffset)
            .padding(16)
        }
        .clipped()
    }

    @ViewBuilder
    private var canvasBackdropView: some View {
        switch controller.s2Backdrop {
        case .whitePaper:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        case .transparentLight:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.92))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        case .transparentDark:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.18))
                .shadow(color: .black.opacity(0.45), radius: 14, y: 4)
        }
    }

    // MARK: - Right Brush & Color Inspector Drawer

    private var brushAndColorInspectorDrawer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Brushes & Color")
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
                        .padding(.vertical, 7)
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

    // MARK: - Drawing, Rulers & Persistent Stroke Handling

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
        #if canImport(MangaCoreFFI)
        if let engine = controller.rustCanvas {
            let label = controller.s2CanvasPreset == .b4PrintManga600Dpi ? "B4 600DPI" : "Webtoon 1600px"
            canvasDimensions = "\(engine.width) × \(engine.height) (\(label))"
        }
        #endif
    }

    private func handleCanvasDragChanged(at point: CGPoint) {
        if let activeLayer = controller.selectedCelLayer {
            if !activeLayer.visible {
                statusLine = "Layer '\(activeLayer.name)' is hidden."
                return
            }
            if activeLayer.alphaLock && !controller.s2Strokes.contains(where: { $0.layerId == activeLayer.id }) {
                statusLine = "Alpha Lock (🔒) protects empty pixels on '\(activeLayer.name)'."
                return
            }
        }

        let isEraser = controller.s2Tool == .eraser
        let width = max(1.0, controller.s2BrushSize)

        if activeStroke == nil {
            activeStroke = PersistedCanvasStroke(
                layerId: controller.s2SelectedLayerId,
                points: [PersistedStrokePoint(x: Double(point.x), y: Double(point.y), width: width)],
                color: controller.s2ActiveColor,
                opacity: controller.s2BrushOpacity,
                isEraser: isEraser,
                tool: controller.s2Tool
            )
            #if canImport(MangaCoreFFI)
            let c = controller.s2ActiveColor
            controller.rustCanvas?.beginStroke(
                radius: Float(width * 0.5),
                rgba: isEraser ? (255, 255, 255, 255) : (c.r, c.g, c.b, c.a),
                isEraser: isEraser,
                stabilizerRadius: Float(controller.s2StabilizerPx)
            )
            #endif
        } else {
            activeStroke?.points.append(PersistedStrokePoint(x: Double(point.x), y: Double(point.y), width: width))
        }

        #if canImport(MangaCoreFFI)
        let sample = NativeStrokeSample(
            x: Float(point.x),
            y: Float(point.y),
            pressure: 0.85,
            altitude: 1.25,
            azimuth: 0.0,
            rollAngle: 0.0,
            timestampMs: Date().timeIntervalSince1970 * 1000.0,
            isPredicted: false
        )
        controller.rustCanvas?.pushPoints([sample])
        if let engine = controller.rustCanvas {
            controller.s2AllocatedTiles = engine.allocatedTiles
        }
        #endif
    }

    private func handleCanvasDragEnded() {
        if var finished = activeStroke {
            if controller.s2ForceFade && finished.points.count >= 6 {
                let count = finished.points.count
                let fadeLen = min(6, count / 3)
                for i in 0..<fadeLen {
                    let t = Double(i + 1) / Double(fadeLen + 1)
                    finished.points[i].width *= t
                    finished.points[count - 1 - i].width *= t
                }
            }
            controller.s2Strokes.append(finished)
            controller.s2UndoneStrokes.removeAll()
            activeStroke = nil
            controller.markDirtyAndScheduleSave()
        }
        #if canImport(MangaCoreFFI)
        if let engine = controller.rustCanvas {
            let dirty = engine.endStroke()
            controller.s2AllocatedTiles = engine.allocatedTiles
            statusLine = "Committed \(controller.s2Tool.displayName) (\(dirty) dirty tiles, auto-saved)."
        }
        #endif
    }

    private func renderAllCelLayers(in context: inout GraphicsContext) {
        let activeLayers = controller.s2CelLayers.isEmpty
            ? [CelLayerRowItem(id: controller.s2SelectedLayerId, name: "Default")]
            : controller.s2CelLayers

        var lastBaseHasContent = false
        for layer in activeLayers {
            let layerStrokes = controller.s2Strokes.filter { $0.layerId == layer.id }
            let liveStroke = (activeStroke?.layerId == layer.id) ? activeStroke : nil
            let hasContent = !layerStrokes.isEmpty || liveStroke != nil

            if !layer.visible || layer.opacity <= 0.001 {
                if !layer.clippingMask { lastBaseHasContent = false }
                continue
            }
            if !layer.clippingMask {
                lastBaseHasContent = hasContent
            } else if !lastBaseHasContent {
                continue
            }

            context.drawLayer { layerCtx in
                layerCtx.opacity = layer.opacity
                layerCtx.blendMode = layer.blendMode.swiftUIBlendMode
                for stroke in layerStrokes {
                    render(stroke, blueSketchTint: layer.blueSketchTint, in: &layerCtx)
                }
                if let liveStroke {
                    render(liveStroke, blueSketchTint: layer.blueSketchTint, in: &layerCtx)
                }
            }
        }
    }

    private func render(_ stroke: PersistedCanvasStroke, blueSketchTint: Bool, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else { return }
        let color: Color
        if stroke.isEraser {
            color = .white
        } else if blueSketchTint {
            color = Color(red: 0.30, green: 0.65, blue: 1.0).opacity(stroke.opacity)
        } else {
            color = stroke.color.swiftUIColor.opacity(stroke.opacity)
        }
        for idx in 1..<stroke.points.count {
            var seg = Path()
            let p0 = stroke.points[idx - 1]
            let p1 = stroke.points[idx]
            seg.move(to: CGPoint(x: p0.x, y: p0.y))
            seg.addLine(to: CGPoint(x: p1.x, y: p1.y))
            context.stroke(
                seg,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(0.8, p1.width), lineCap: .round, lineJoin: .round)
            )
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
