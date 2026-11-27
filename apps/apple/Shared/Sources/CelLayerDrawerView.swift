import Foundation

#if canImport(SwiftUI)
import SwiftUI

public struct CelLayerRowItem: Identifiable, Equatable, Sendable {
    public var id: UInt64
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

/// `S2 v1.0-rc2` — ibisPaint-aligned Right Cel Layer Drawer with full CRUD
/// (Add / Duplicate / Delete / Merge Down / Reorder Up-Down / Clear) +
/// `R` Reference / `✂` Clipping / `🔒` Alpha Lock / `B` Blue Sketch + zero-overlap layout.
public struct CelLayerDrawerView: View {
    @Binding public var layers: [CelLayerRowItem]
    @Binding public var selectedLayerId: UInt64
    public let onAddLayer: () -> Void
    public let onDuplicateLayer: () -> Void
    public let onDeleteLayer: () -> Void
    public let onMergeDown: () -> Void
    public let onMoveLayer: (UInt64, Bool) -> Void
    public let onClearLayer: () -> Void
    public let onUpdateLayer: (CelLayerRowItem) -> Void

    public init(
        layers: Binding<[CelLayerRowItem]>,
        selectedLayerId: Binding<UInt64>,
        onAddLayer: @escaping () -> Void,
        onDuplicateLayer: @escaping () -> Void = {},
        onDeleteLayer: @escaping () -> Void = {},
        onMergeDown: @escaping () -> Void = {},
        onMoveLayer: @escaping (UInt64, Bool) -> Void = { _, _ in },
        onClearLayer: @escaping () -> Void = {},
        onUpdateLayer: @escaping (CelLayerRowItem) -> Void
    ) {
        self._layers = layers
        self._selectedLayerId = selectedLayerId
        self.onAddLayer = onAddLayer
        self.onDuplicateLayer = onDuplicateLayer
        self.onDeleteLayer = onDeleteLayer
        self.onMergeDown = onMergeDown
        self.onMoveLayer = onMoveLayer
        self.onClearLayer = onClearLayer
        self.onUpdateLayer = onUpdateLayer
    }

    private var selectedIndex: Int? {
        layers.firstIndex(where: { $0.id == selectedLayerId })
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Layers (\(layers.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    iconActionButton(symbol: "plus", help: "New Layer (⇧⌘N)", accent: true, action: onAddLayer)
                    iconActionButton(symbol: "plus.square.on.square", help: "Duplicate Layer (⌘J)", action: onDuplicateLayer)
                        .disabled(selectedIndex == nil)
                    iconActionButton(symbol: "square.stack.3d.down.right", help: "Merge Down (⌘E)", action: onMergeDown)
                        .disabled((selectedIndex ?? 0) <= 0)
                    iconActionButton(symbol: "trash", help: "Delete Layer", action: onDeleteLayer)
                        .disabled(layers.isEmpty || selectedIndex == nil)
                }

                if let idx = selectedIndex {
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

    private func iconActionButton(symbol: String, help: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(accent ? SuiteColorTokens.mangaAccent : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func activeLayerControls(index: Int) -> some View {
        let layer = layers[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
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
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(SuiteColorTokens.mangaAccent)

                Spacer(minLength: 4)

                Button("Clear") {
                    onClearLayer()
                }
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                Text("\(Int(layer.opacity * 100))%")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.white.opacity(0.78))
                    .frame(width: 36, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                Slider(value: Binding(
                    get: { layers[index].opacity },
                    set: { newOpacity in
                        layers[index].opacity = newOpacity
                        onUpdateLayer(layers[index])
                    }
                ), in: 0.0...1.0)
                .tint(SuiteColorTokens.mangaAccent)
            }

            // Quick Flags: R (Reference) / ✂ (Clip) / 🔒 (Alpha Lock) / B (Blue Sketch)
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
                .lineLimit(1)
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
        return HStack(spacing: 6) {
            Button {
                layers[index].visible.toggle()
                onUpdateLayer(layers[index])
            } label: {
                Image(systemName: item.visible ? "eye.fill" : "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(item.visible ? Color.white.opacity(0.88) : Color.white.opacity(0.32))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("Toggle layer visibility")

            Button {
                selectedLayerId = item.id
            } label: {
                HStack(spacing: 6) {
                    if item.clippingMask {
                        Text("↳")
                            .font(.caption2.bold())
                            .foregroundStyle(SuiteColorTokens.mangaAccent)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.caption.weight(selected ? .bold : .regular))
                            .foregroundStyle(
                                !item.visible
                                    ? Color.white.opacity(0.35)
                                    : (item.blueSketchTint ? Color(red: 0.38, green: 0.68, blue: 1.0) : .white)
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("\(item.blendMode.displayName) · \(Int(item.opacity * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    .layoutPriority(0)
                    Spacer(minLength: 4)
                    HStack(spacing: 2) {
                        if item.isReference { badge("R") }
                        if item.clippingMask { badge("✂") }
                        if item.alphaLock { badge("🔒") }
                        if item.blueSketchTint { badge("B") }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(2)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Button {
                    onMoveLayer(item.id, true)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(index < layers.count - 1 ? Color.white.opacity(0.75) : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(index >= layers.count - 1)

                Button {
                    onMoveLayer(item.id, false)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(index > 0 ? Color.white.opacity(0.75) : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(index <= 0)
            }
            .fixedSize()
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

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(SuiteColorTokens.mangaAccent.opacity(0.32))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
#endif
