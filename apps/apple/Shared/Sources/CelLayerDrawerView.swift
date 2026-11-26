import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct CelLayerRowItem: Identifiable, Sendable {
    public let id: UInt64
    public var name: String
    public var visible: Bool
    public var isReference: Bool
    public var clippingMask: Bool
    public var alphaLock: Bool
    public var blueSketchTint: Bool
    public var blendMode: LayerBlendMode
    public var opacity: Double

    public init(
        id: UInt64,
        name: String,
        visible: Bool = true,
        isReference: Bool = false,
        clippingMask: Bool = false,
        alphaLock: Bool = false,
        blueSketchTint: Bool = false,
        blendMode: LayerBlendMode = .normal,
        opacity: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.visible = visible
        self.isReference = isReference
        self.clippingMask = clippingMask
        self.alphaLock = alphaLock
        self.blueSketchTint = blueSketchTint
        self.blendMode = blendMode
        self.opacity = opacity
    }
}

/// `S2 v0.3.1` — Right Cel Layer Drawer (`R` Reference / `✂` Clipping / `🔒` Alpha Lock / `B` Blue Sketch
/// + all 13 anime cel-shading blend modes) synced live to Rust `MangaProjectEngine`.
public struct CelLayerDrawerView: View {
    @Binding public var layers: [CelLayerRowItem]
    @Binding public var selectedLayerId: UInt64
    public let onAddLayer: () -> Void
    public let onUpdateLayer: (CelLayerRowItem) -> Void

    public init(
        layers: Binding<[CelLayerRowItem]>,
        selectedLayerId: Binding<UInt64>,
        onAddLayer: @escaping () -> Void,
        onUpdateLayer: @escaping (CelLayerRowItem) -> Void
    ) {
        self._layers = layers
        self._selectedLayerId = selectedLayerId
        self.onAddLayer = onAddLayer
        self.onUpdateLayer = onUpdateLayer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Cel Layers (\(layers.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        onAddLayer()
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(SuiteColorTokens.mangaAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if let idx = layers.firstIndex(where: { $0.id == selectedLayerId }) {
                    activeLayerControls(index: idx)
                }

                Divider().background(SuiteColorTokens.mangaBorder)

                ForEach(layers.indices.reversed(), id: \.self) { idx in
                    layerRow(index: idx)
                }
            }
            .padding(12)
        }
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    private func activeLayerControls(index: Int) -> some View {
        let layer = layers[index]
        return VStack(alignment: .leading, spacing: 8) {
            Picker("Blend", selection: Binding(
                get: { layers[index].blendMode },
                set: { newMode in
                    layers[index].blendMode = newMode
                    onUpdateLayer(layers[index])
                }
            )) {
                ForEach(LayerBlendMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(SuiteColorTokens.mangaAccent)

            HStack {
                Text("Opacity \(Int(layer.opacity * 100))%")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.white.opacity(0.75))
                Slider(value: Binding(
                    get: { layers[index].opacity },
                    set: { newOpacity in
                        layers[index].opacity = newOpacity
                        onUpdateLayer(layers[index])
                    }
                ), in: 0.0...1.0)
                .tint(SuiteColorTokens.mangaAccent)
            }

            // S2 v0.3.1 Quick Flags: R (Reference) / ✂ (Clip) / 🔒 (Alpha Lock) / B (Blue Sketch)
            HStack(spacing: 6) {
                flagToggle("R", active: layer.isReference) {
                    layers[index].isReference.toggle()
                    onUpdateLayer(layers[index])
                }
                flagToggle("✂", active: layer.clippingMask) {
                    layers[index].clippingMask.toggle()
                    onUpdateLayer(layers[index])
                }
                flagToggle("🔒", active: layer.alphaLock) {
                    layers[index].alphaLock.toggle()
                    onUpdateLayer(layers[index])
                }
                flagToggle("B", active: layer.blueSketchTint) {
                    layers[index].blueSketchTint.toggle()
                    onUpdateLayer(layers[index])
                }
            }
        }
    }

    private func flagToggle(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(active ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func layerRow(index: Int) -> some View {
        let item = layers[index]
        let selected = item.id == selectedLayerId
        return Button {
            selectedLayerId = item.id
        } label: {
            HStack(spacing: 6) {
                if item.clippingMask {
                    Text("↳")
                        .font(.caption2.bold())
                        .foregroundStyle(SuiteColorTokens.mangaAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.caption.weight(selected ? .bold : .regular))
                        .foregroundStyle(item.blueSketchTint ? Color(red: 0.38, green: 0.68, blue: 1.0) : .white)
                        .lineLimit(1)
                    Text("\(item.blendMode.displayName) · \(Int(item.opacity * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                Spacer()
                HStack(spacing: 3) {
                    if item.isReference { badge("R") }
                    if item.alphaLock { badge("🔒") }
                    if item.blueSketchTint { badge("B") }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(selected ? SuiteColorTokens.mangaAccent.opacity(0.22) : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? SuiteColorTokens.mangaAccent : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(SuiteColorTokens.mangaAccent.opacity(0.3))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
#endif
