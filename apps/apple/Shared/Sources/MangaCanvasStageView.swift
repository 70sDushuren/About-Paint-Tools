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
    var points: [CGPoint]
    var widths: [CGFloat]
    var color: Color
    var isEraser: Bool
}

/// `S2 v0.2.2` — `雕龙 / DracoNib` (Working Codename) studio workspace:
/// Zero-tint OLED Studio Charcoal (#111216) + Crimson-Coral (#FF6B4A) + 56px Icon Rail +
/// 8 Dual-Track Anime Brush Presets + live Rust `MangaBrushDynamics` & `MangaCanvasEngine` FFI.
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
    @State private var strokes: [CanvasStrokeRecord] = []
    @State private var undoneStrokes: [CanvasStrokeRecord] = []
    @State private var activeStroke: CanvasStrokeRecord?
    @State private var allocatedTiles: Int = 0
    @State private var canvasDimensions: String = "6071 × 8598 (B4 600DPI)"
    @State private var statusLine: String = "Zero-allocation B4 600DPI sparse canvas ready."

    #if canImport(MangaCoreFFI)
    @State private var rustCanvas: MangaCanvasEngine?
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

            if showBrushDrawer && layout != .singlePaneCompact {
                brushDynamicsDrawer
                    .frame(width: 248)
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
                summary: "13 cel blend modes, clipping masks & alpha lock (v0.3 drawer).",
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

                Text(canvasDimensions)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.white.opacity(0.7))

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
                    for stroke in strokes {
                        render(stroke, in: &context)
                    }
                    if let activeStroke {
                        render(activeStroke, in: &context)
                    }
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

                Text("Rust CoW Tiles: \(allocatedTiles) · Effective Radius: \(String(format: "%.1fpx", currentRustRadius)) · Rope: \(String(format: "%.1fpx", currentAdaptiveRope))")
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
            }
            .padding(12)
        }
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
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
        case "stabilizer": return showBrushDrawer
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
            showBrushDrawer.toggle()
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
        #endif
    }

    private func handleDragChanged(at point: CGPoint) {
        let radius = max(1.0, CGFloat(currentRustRadius))
        if activeStroke == nil {
            activeStroke = CanvasStrokeRecord(
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

    private func render(_ stroke: CanvasStrokeRecord, in context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else { return }
        let color: Color = stroke.isEraser ? .white : stroke.color
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
