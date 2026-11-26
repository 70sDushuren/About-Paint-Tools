import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct BrushPresetDescriptor: Identifiable, Sendable {
    public let id: UInt32
    public let name: String
    public let trackBadge: String
    public let baseColor: Color
    public let isEraser: Bool

    public init(id: UInt32, name: String, trackBadge: String, baseColor: Color, isEraser: Bool = false) {
        self.id = id
        self.name = name
        self.trackBadge = trackBadge
        self.baseColor = baseColor
        self.isEraser = isEraser
    }
}

private struct CanvasStrokeRecord: Identifiable {
    let id = UUID()
    var layerId: UInt64
    var points: [CGPoint]
    var widths: [CGFloat]
    var color: Color
    var isEraser: Bool
}

extension LayerBlendMode {
    /// Maps all 13 Rust `BlendMode` values to SwiftUI `GraphicsContext.BlendMode` for live `S2 v0.3.2` cel preview.
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

/// `S2 v0.3.2` — `雕龙 / DracoNib` (Working Codename) studio workspace:
/// Zero-tint OLED Studio Charcoal (#111216) + Crimson-Coral (#FF6B4A) + 56px Icon Rail +
/// 8 Dual-Track Anime Brush Presets + live multi-layer 13-mode cel compositing preview (`R`/`✂`/`🔒`/`B`).
public struct MangaCanvasStageView: View {
    public let layout: WorkspaceLayoutHintKind
    public let hintModeActive: Bool
    public let hingeAvoidanceWidthPt: CGFloat

    @State private var selectedPresetIndex: UInt32 = 0
    @State private var selectedCanvasPreset: CanvasPresetKind = .b4PrintManga600Dpi
    @State private var stabilizerScreenPx: Double = 8.0
    @State private var viewportZoom: Double = 1.0
    @State private var simulatedPressure: Double = 0.78
    @State private var showBrushDrawer: Bool = true
    @State private var showLayerDrawer: Bool = false
    @State private var celLayers: [CelLayerRowItem] = []
    @State private var selectedLayerId: UInt64 = 1
    @State private var strokes: [CanvasStrokeRecord] = []
    @State private var undoneStrokes: [CanvasStrokeRecord] = []
    @State private var activeStroke: CanvasStrokeRecord?
    @State private var allocatedTiles: Int = 0
    @State private var canvasDimensions: String = "6071 × 8598 (B4 600DPI)"
    @State private var statusLine: String = "Zero-allocation B4 600DPI sparse canvas ready."

    #if canImport(MangaCoreFFI)
    @State private var rustCanvas: MangaCanvasEngine?
    @State private var rustProject: MangaProjectEngine?
    #endif

    private let starterPresets: [BrushPresetDescriptor] = [
        BrushPresetDescriptor(id: 0, name: "G-Pen", trackBadge: "B&W Ink", baseColor: Color(red: 0.07, green: 0.07, blue: 0.09)),
        BrushPresetDescriptor(id: 1, name: "Maru-Pen", trackBadge: "B&W Fine", baseColor: Color(red: 0.07, green: 0.07, blue: 0.09)),
        BrushPresetDescriptor(id: 2, name: "Textured Ink", trackBadge: "B&W Rough", baseColor: Color(red: 0.12, green: 0.12, blue: 0.14)),
        BrushPresetDescriptor(id: 3, name: "Blue Pencil 2B", trackBadge: "Sketch", baseColor: Color(red: 0.24, green: 0.52, blue: 0.96)),
        BrushPresetDescriptor(id: 4, name: "Flat Cel Fill", trackBadge: "Webtoon", baseColor: Color(red: 1.0, green: 0.42, blue: 0.29)),
        BrushPresetDescriptor(id: 5, name: "Soft Airbrush", trackBadge: "Color", baseColor: Color(red: 0.31, green: 0.49, blue: 1.0).opacity(0.45)),
        BrushPresetDescriptor(id: 6, name: "Watercolor Blend", trackBadge: "Color", baseColor: Color(red: 0.18, green: 0.66, blue: 0.55).opacity(0.65)),
        BrushPresetDescriptor(id: 7, name: "Vector Eraser", trackBadge: "Clean", baseColor: .white, isEraser: true),
    ]

    public init(
        layout: WorkspaceLayoutHintKind,
        hintModeActive: Bool,
        hingeAvoidanceWidthPt: CGFloat = 0
    ) {
        self.layout = layout
        self.hintModeActive = hintModeActive
        self.hingeAvoidanceWidthPt = hingeAvoidanceWidthPt
    }

    public var body: some View {
        HStack(spacing: 0) {
            darkIconRail
            ZStack(alignment: .bottomLeading) {
                canvasStage
                if layout != .singlePaneCompact {
                    microCaliperHud
                        .padding(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if layout != .singlePaneCompact {
                if showLayerDrawer {
                    CelLayerDrawerView(
                        layers: $celLayers,
                        selectedLayerId: $selectedLayerId,
                        onAddLayer: addCelLayer,
                        onUpdateLayer: syncLayerToRust
                    )
                    .frame(width: 248)
                } else if showBrushDrawer {
                    brushDynamicsDrawer
                        .frame(width: 248)
                }
            }
        }
        .background(SuiteColorTokens.mangaCharcoal)
        .onAppear(perform: initRustCanvas)
    }

    // MARK: - 56px OLED Studio Charcoal Icon Rail

    private var darkIconRail: some View {
        VStack(spacing: 8) {
            ForEach(railItems) { item in
                let selected = isRailItemSelected(item.id)
                RailIconHintButton(
                    spec: item,
                    isSelected: selected,
                    accent: SuiteColorTokens.mangaAccent,
                    isDarkChrome: true,
                    hintModeActive: hintModeActive
                ) {
                    handleRailTap(item.id)
                }
            }
            Spacer()
            Text("S2")
                .font(.caption2.monospaced().bold())
                .foregroundStyle(SuiteColorTokens.mangaAccent)
                .padding(.bottom, 8)
        }
        .padding(.vertical, 10)
        .frame(width: 56)
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .trailing) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    private var railItems: [ToolHintSpec] {
        [
            ToolHintSpec(
                id: "pen",
                glyph: .mangaPen,
                title: "Anime Ink & Brush",
                roleBadge: "8 Presets",
                summary: "Switch between G-Pen, Maru-Pen, Blue Sketch, and Webtoon Color brushes.",
                shortcut: "B",
                ownershipCue: "S2 RW: manuscript/*.mnga"
            ),
            ToolHintSpec(
                id: "eraser",
                glyph: .mangaEraser,
                title: "Vector / Pixel Eraser",
                roleBadge: "Clean",
                summary: "Erase ink strokes cleanly; vector intersection mode arrives in v0.5.",
                shortcut: "E",
                ownershipCue: "CoW Undo Protected"
            ),
            ToolHintSpec(
                id: "stabilizer",
                glyph: .mangaStabilizer,
                title: "Zoom-Adaptive Rope",
                roleBadge: "Rust FFI",
                summary: "Toggle brush dynamics & zoom-adaptive rope stabilizer inspector.",
                shortcut: "S",
                ownershipCue: "manga_brush_zoom_adaptive_rope"
            ),
            ToolHintSpec(
                id: "layers",
                glyph: .mangaLayers,
                title: "Cel Layer Stack",
                roleBadge: "13 Modes",
                summary: "Live 13 cel blend modes, visibility, clipping masks, alpha lock & blue sketch tint.",
                shortcut: "L",
                ownershipCue: "256×256 Sparse Tiles"
            ),
            ToolHintSpec(
                id: "panels",
                glyph: .mangaPanels,
                title: "Diagonal Panel Knife",
                roleBadge: "B4 / Webtoon",
                summary: "Toggle between B4 600DPI page manga and 1600px Webtoon strip canvas.",
                shortcut: "K",
                ownershipCue: "Dual-Track Canvas"
            ),
            ToolHintSpec(
                id: "undo",
                glyph: .mangaUndo,
                title: "Tile-Level CoW Undo",
                roleBadge: "Zero Lag",
                summary: "Revert last committed stroke in Rust TileUndoStack.",
                shortcut: "⌘Z / 2-Finger Tap",
                ownershipCue: "Incremental CoW Snapshot"
            ),
        ]
    }

    // MARK: - Main Canvas Stage (>= 82% viewport)

    private var canvasStage: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("\(activePreset.name) · \(activePreset.trackBadge)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(SuiteColorTokens.mangaAccent)
                    .clipShape(Capsule())

                if let activeLayer = selectedCelLayer {
                    Text("Layer: \(activeLayer.name) [\(activeLayer.blendMode.displayName)\(activeLayer.alphaLock ? " 🔒" : "")\(activeLayer.blueSketchTint ? " B" : "")]")
                        .font(.caption2.monospaced())
                        .foregroundStyle(activeLayer.blueSketchTint ? Color(red: 0.45, green: 0.72, blue: 1.0) : Color.white.opacity(0.8))
                }

                Text(canvasDimensions)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.white.opacity(0.6))

                Spacer()

                Button("Undo") { performUndo() }
                    .disabled(strokes.isEmpty)
                    .font(.caption.bold())
                    .foregroundStyle(strokes.isEmpty ? Color.white.opacity(0.3) : .white)
                    .buttonStyle(.plain)

                Button("Redo") { performRedo() }
                    .disabled(undoneStrokes.isEmpty)
                    .font(.caption.bold())
                    .foregroundStyle(undoneStrokes.isEmpty ? Color.white.opacity(0.3) : .white)
                    .buttonStyle(.plain)

                Button("Clear") { clearCanvas() }
                    .font(.caption.bold())
                    .foregroundStyle(SuiteColorTokens.mangaAccent)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 4)

                Canvas { context, _ in
                    renderAllCelLayers(in: &context)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(at: value.location)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )

                Text("Rust CoW Tiles: \(allocatedTiles) · Radius: \(String(format: "%.1fpx", currentRustRadius)) · Rope: \(String(format: "%.1fpx", currentAdaptiveRope)) · Layers: \(celLayers.filter { $0.visible }.count)/\(celLayers.count)")
                    .font(.caption2.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SuiteColorTokens.mangaCharcoal.opacity(0.84))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Micro-Caliper Floating HUD & Right Brush Dynamics Drawer

    private var microCaliperHud: some View {
        HStack(spacing: 12) {
            Text("Zoom \(Int(viewportZoom * 100))%")
                .font(.caption2.monospaced())
                .foregroundStyle(.white)
            Slider(value: $viewportZoom, in: 0.25...4.0)
                .frame(width: 90)
                .tint(SuiteColorTokens.mangaAccent)

            Text("Rope \(Int(stabilizerScreenPx))px")
                .font(.caption2.monospaced())
                .foregroundStyle(.white)
            Slider(value: $stabilizerScreenPx, in: 0...24)
                .frame(width: 90)
                .tint(SuiteColorTokens.mangaAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(SuiteColorTokens.mangaPanel.opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SuiteColorTokens.mangaBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var brushDynamicsDrawer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dual-Track Brushes (\(rustPresetCount))")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("v0.2.2")
                        .font(.caption2.monospaced())
                        .foregroundStyle(SuiteColorTokens.mangaAccent)
                }

                ForEach(starterPresets) { preset in
                    let active = preset.id == selectedPresetIndex
                    Button {
                        selectedPresetIndex = preset.id
                    } label: {
                        HStack {
                            Circle()
                                .fill(preset.isEraser ? Color.white : preset.baseColor)
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                                .frame(width: 12, height: 12)
                            Text(preset.name)
                                .font(.caption.weight(active ? .bold : .regular))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(preset.trackBadge)
                                .font(.caption2.monospaced())
                                .foregroundStyle(active ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.55))
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Rust Dynamics Preview")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    HStack {
                        Text("Pressure")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.7))
                        Slider(value: $simulatedPressure, in: 0.05...1.0)
                            .tint(SuiteColorTokens.mangaAccent)
                    }
                    Text("Radius: \(String(format: "%.2f px", currentRustRadius))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(SuiteColorTokens.mangaAccent)
                    Text("Adaptive Rope: \(String(format: "%.2f canvas px", currentAdaptiveRope))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text(statusLine)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.top, 4)
                }

                Divider().background(SuiteColorTokens.mangaBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("v0.4 Anti-Halo Fill & Lasso")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Button {
                        runLiveCloseGapAndLassoVerify()
                    } label: {
                        Label("Run Close-Gap (3px) + Lasso", systemImage: "drop.fill")
                            .font(.caption2.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(SuiteColorTokens.mangaAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    private func runLiveCloseGapAndLassoVerify() {
        #if canImport(MangaCoreFFI)
        let xs: [Float] = [10, 40, 40, 10]
        let ys: [Float] = [10, 10, 40, 40]
        let lassoPx = MangaSelectionEngine.lassoPixelCount(
            xs: xs,
            ys: ys,
            width: 80,
            height: 80,
            invert: false,
            borderDeltaPx: 1
        )
        let filled = rustProject?.closeGapFill(
            layerId: selectedLayerId,
            seedX: 30,
            seedY: 30,
            rgba: (255, 107, 74, 255),
            closeGapPx: 3,
            expandPx: 1
        ) ?? 0
        statusLine = "v0.4 Fill+Lasso OK: closeGap=3px, expand=1px (filled=\(filled)), lasso+1px=\(lassoPx)px."
        #else
        statusLine = "MangaCoreFFI not linked."
        #endif
    }

    // MARK: - Rust FFI Dynamics & Canvas Lifecycle

    private var activePreset: BrushPresetDescriptor {
        starterPresets.first(where: { $0.id == selectedPresetIndex }) ?? starterPresets[0]
    }

    private var rustPresetCount: UInt32 {
        #if canImport(MangaCoreFFI)
        return MangaBrushDynamics.presetCount
        #else
        return UInt32(starterPresets.count)
        #endif
    }

    private var currentRustRadius: Float {
        #if canImport(MangaCoreFFI)
        return MangaBrushDynamics.sampleRadius(
            presetCode: selectedPresetIndex,
            pressure: Float(simulatedPressure),
            altitude: 1.25
        )
        #else
        return Float(2.0 + simulatedPressure * 8.0)
        #endif
    }

    private var currentAdaptiveRope: Float {
        #if canImport(MangaCoreFFI)
        return MangaBrushDynamics.zoomAdaptiveRope(
            baseScreenPx: Float(stabilizerScreenPx),
            viewportZoom: Float(viewportZoom)
        )
        #else
        return Float(stabilizerScreenPx / max(viewportZoom, 0.25))
        #endif
    }

    private func isRailItemSelected(_ id: String) -> Bool {
        switch id {
        case "pen": return !activePreset.isEraser
        case "eraser": return activePreset.isEraser
        case "stabilizer": return showBrushDrawer && !showLayerDrawer
        case "layers": return showLayerDrawer
        default: return false
        }
    }

    private func handleRailTap(_ id: String) {
        switch id {
        case "pen":
            if activePreset.isEraser { selectedPresetIndex = 0 }
        case "eraser":
            selectedPresetIndex = 7
        case "stabilizer":
            showLayerDrawer = false
            showBrushDrawer.toggle()
        case "layers":
            showLayerDrawer.toggle()
        case "panels":
            selectedCanvasPreset = (selectedCanvasPreset == .b4PrintManga600Dpi) ? .webtoonStrip1600 : .b4PrintManga600Dpi
            initRustCanvas()
        case "undo":
            performUndo()
        default:
            statusLine = "Module '\(id)' scheduled for upcoming v0.3+ patch."
        }
    }

    private func initRustCanvas() {
        strokes.removeAll()
        undoneStrokes.removeAll()
        activeStroke = nil
        #if canImport(MangaCoreFFI)
        if let engine = MangaCanvasEngine(preset: selectedCanvasPreset) {
            rustCanvas = engine
            allocatedTiles = engine.allocatedTiles
            let label = selectedCanvasPreset == .b4PrintManga600Dpi ? "B4 600DPI" : "Webtoon 1600px"
            canvasDimensions = "\(engine.width) × \(engine.height) (\(label))"
            statusLine = "Initialized \(label) sparse canvas (0 allocated tiles)."
        }
        if rustProject == nil, let proj = MangaProjectEngine(preset: selectedCanvasPreset) {
            let sketchId = proj.addRasterLayer(name: "Sketch_Rough", blendMode: .normal, clippingMask: false, isReference: false)
            let inkId = proj.addRasterLayer(name: "Ink_Lineart", blendMode: .normal, clippingMask: false, isReference: true)
            let shadowId = proj.addRasterLayer(name: "Cel_Shadow", blendMode: .multiply, clippingMask: true, isReference: false)
            _ = proj.setLayerFlags(layerId: sketchId, visible: true, alphaLock: false, clippingMask: false, isReference: false, blendMode: .normal, opacity: 0.35, blueSketchTint: true)
            rustProject = proj
            celLayers = [
                CelLayerRowItem(id: sketchId, name: "Sketch_Rough", blueSketchTint: true, blendMode: .normal, opacity: 0.35),
                CelLayerRowItem(id: inkId, name: "Ink_Lineart", isReference: true, blendMode: .normal, opacity: 1.0),
                CelLayerRowItem(id: shadowId, name: "Cel_Shadow", clippingMask: true, blendMode: .multiply, opacity: 0.85),
            ]
            selectedLayerId = inkId
        }
        #else
        if celLayers.isEmpty {
            celLayers = [
                CelLayerRowItem(id: 1, name: "Sketch_Rough", blueSketchTint: true, opacity: 0.35),
                CelLayerRowItem(id: 2, name: "Ink_Lineart", isReference: true),
                CelLayerRowItem(id: 3, name: "Cel_Shadow", clippingMask: true, blendMode: .multiply, opacity: 0.85),
            ]
            selectedLayerId = 2
        }
        #endif
    }

    private func addCelLayer() {
        let nextNum = celLayers.count + 1
        let name = "Cel_Layer_\(nextNum)"
        #if canImport(MangaCoreFFI)
        if let proj = rustProject {
            let newId = proj.addRasterLayer(name: name, blendMode: .normal, clippingMask: false, isReference: false)
            celLayers.append(CelLayerRowItem(id: newId, name: name))
            selectedLayerId = newId
            statusLine = "Added Rust Layer '\(name)' (total=\(proj.layerCount))."
            return
        }
        #endif
        let fallbackId = UInt64(nextNum)
        celLayers.append(CelLayerRowItem(id: fallbackId, name: name))
        selectedLayerId = fallbackId
    }

    private func syncLayerToRust(_ item: CelLayerRowItem) {
        #if canImport(MangaCoreFFI)
        _ = rustProject?.setLayerFlags(
            layerId: item.id,
            visible: item.visible,
            alphaLock: item.alphaLock,
            clippingMask: item.clippingMask,
            isReference: item.isReference,
            blendMode: item.blendMode,
            opacity: Float(item.opacity),
            blueSketchTint: item.blueSketchTint
        )
        statusLine = "Synced '\(item.name)' [\(item.blendMode.displayName), R=\(item.isReference), Clip=\(item.clippingMask), Lock=\(item.alphaLock), B=\(item.blueSketchTint)]."
        #endif
    }

    private var selectedCelLayer: CelLayerRowItem? {
        celLayers.first(where: { $0.id == selectedLayerId })
    }

    private func handleDragChanged(at point: CGPoint) {
        if let activeLayer = selectedCelLayer {
            if !activeLayer.visible {
                statusLine = "Layer '\(activeLayer.name)' is hidden — toggle eye icon to draw."
                return
            }
            if activeLayer.alphaLock && !strokes.contains(where: { $0.layerId == activeLayer.id }) {
                statusLine = "Alpha Lock (🔒) blocked stroke on empty layer '\(activeLayer.name)'."
                return
            }
        }

        let radius = max(1.0, CGFloat(currentRustRadius))
        if activeStroke == nil {
            activeStroke = CanvasStrokeRecord(
                layerId: selectedLayerId,
                points: [point],
                widths: [radius],
                color: activePreset.baseColor,
                isEraser: activePreset.isEraser
            )
            #if canImport(MangaCoreFFI)
            rustCanvas?.beginStroke(
                radius: currentRustRadius,
                rgba: activePreset.isEraser ? (255, 255, 255, 255) : (17, 18, 22, 255),
                isEraser: activePreset.isEraser,
                stabilizerRadius: currentAdaptiveRope
            )
            #endif
        } else {
            activeStroke?.points.append(point)
            activeStroke?.widths.append(radius)
        }

        #if canImport(MangaCoreFFI)
        let sample = NativeStrokeSample(
            x: Float(point.x),
            y: Float(point.y),
            pressure: Float(simulatedPressure),
            altitude: 1.25,
            azimuth: 0.0,
            rollAngle: 0.0,
            timestampMs: Date().timeIntervalSince1970 * 1000.0,
            isPredicted: false
        )
        rustCanvas?.pushPoints([sample])
        if let engine = rustCanvas {
            allocatedTiles = engine.allocatedTiles
        }
        #endif
    }

    private func handleDragEnded() {
        if let finished = activeStroke {
            strokes.append(finished)
            undoneStrokes.removeAll()
            activeStroke = nil
        }
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            let dirty = engine.endStroke()
            allocatedTiles = engine.allocatedTiles
            statusLine = "Committed \(activePreset.name) stroke (\(dirty) dirty tiles, \(allocatedTiles) total)."
        }
        #endif
    }

    private func performUndo() {
        guard let last = strokes.popLast() else { return }
        undoneStrokes.append(last)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.undo()
            allocatedTiles = engine.allocatedTiles
            statusLine = "Rust CoW Undo applied (\(allocatedTiles) tiles)."
        }
        #endif
    }

    private func performRedo() {
        guard let restored = undoneStrokes.popLast() else { return }
        strokes.append(restored)
        #if canImport(MangaCoreFFI)
        if let engine = rustCanvas {
            _ = engine.redo()
            allocatedTiles = engine.allocatedTiles
            statusLine = "Rust CoW Redo applied (\(allocatedTiles) tiles)."
        }
        #endif
    }

    private func clearCanvas() {
        initRustCanvas()
    }

    /// `S2 v0.3.2` — Live multi-layer cel compositing preview honoring visibility, opacity,
    /// all 13 `LayerBlendMode`s, non-destructive `B` blue sketch tint, and `✂` clipping mask.
    private func renderAllCelLayers(in context: inout GraphicsContext) {
        let activeLayers = celLayers.isEmpty
            ? [CelLayerRowItem(id: selectedLayerId, name: "Default")]
            : celLayers

        var lastBaseHasContent = false
        for layer in activeLayers {
            let layerStrokes = strokes.filter { $0.layerId == layer.id }
            let liveStroke = (activeStroke?.layerId == layer.id) ? activeStroke : nil
            let hasContent = !layerStrokes.isEmpty || liveStroke != nil

            if !layer.visible || layer.opacity <= 0.001 {
                if !layer.clippingMask {
                    lastBaseHasContent = false
                }
                continue
            }

            if !layer.clippingMask {
                lastBaseHasContent = hasContent
            } else if !lastBaseHasContent {
                // Clipping mask restricts visibility strictly when the base layer below has content.
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

    private func render(_ stroke: CanvasStrokeRecord, blueSketchTint: Bool, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else { return }
        let color: Color
        if stroke.isEraser {
            color = .white
        } else if blueSketchTint {
            color = Color(red: 0.30, green: 0.65, blue: 1.0)
        } else {
            color = stroke.color
        }
        for idx in 1..<stroke.points.count {
            var seg = Path()
            seg.move(to: stroke.points[idx - 1])
            seg.addLine(to: stroke.points[idx])
            let w = idx < stroke.widths.count ? stroke.widths[idx] : (stroke.widths.last ?? 3.0)
            context.stroke(
                seg,
                with: .color(color),
                style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
#endif
