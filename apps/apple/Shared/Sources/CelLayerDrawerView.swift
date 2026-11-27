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

/// `S2 v1.0-rc5` — ibisPaint-aligned Right Cel Layer Drawer with full CRUD & Stack Reordering
/// (Add / Duplicate / Move Up / Move Down / Merge Down / Delete / Clear) +
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

    private var canMoveSelectedUp: Bool {
        guard let idx = selectedIndex else { return false }
        return idx < layers.count - 1
    }

    private var canMoveSelectedDown: Bool {
        guard let idx = selectedIndex else { return false }
        return idx > 0
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Text("Layers (\(layers.count))")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    iconActionButton(symbol: "plus", help: "新建图层 New Layer (⇧⌘N)", accent: true, action: onAddLayer)
                    iconActionButton(symbol: "plus.square.on.square", help: "复制图层 Duplicate Layer (⌘J)", action: onDuplicateLayer)
                        .disabled(selectedIndex == nil)
                    iconActionButton(
                        symbol: "arrow.up",
                        help: "将选中图层上移一层 (提高堆叠次序)",
                        disabled: !canMoveSelectedUp
                    ) {
                        onMoveLayer(selectedLayerId, true)
                    }
                    iconActionButton(
                        symbol: "arrow.down",
                        help: "将选中图层下移一层 (降低堆叠次序)",
                        disabled: !canMoveSelectedDown
                    ) {
                        onMoveLayer(selectedLayerId, false)
                    }
                    iconActionButton(
                        symbol: "square.stack.3d.down.right",
                        help: "向下合并图层 Merge Down (⌘E)",
                        disabled: (selectedIndex ?? 0) <= 0,
                        action: onMergeDown
                    )
                    iconActionButton(
                        symbol: "trash",
                        help: "删除图层 Delete Layer",
                        disabled: layers.isEmpty || selectedIndex == nil,
                        action: onDeleteLayer
                    )
                }

                if let idx = selectedIndex {
                    activeLayerControls(index: idx)
                }

                Divider().background(SuiteColorTokens.mangaBorder)

                // Stack order hint header
                if layers.count > 1 {
                    HStack {
                        Text("堆叠次序 (上层遮挡下层)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.55))
                        Spacer()
                        Text("上移 ▲ / 下移 ▼")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                    .padding(.horizontal, 2)
                }

                ForEach(Array(layers.enumerated().reversed()), id: \.element.id) { pair in
                    layerRow(index: pair.offset, item: pair.element)
                }
            }
            .padding(12)
        }
        .background(SuiteColorTokens.mangaPanel)
        .overlay(alignment: .leading) {
            Rectangle().fill(SuiteColorTokens.mangaBorder).frame(width: 1)
        }
    }

    private func iconActionButton(
        symbol: String,
        help: String,
        accent: Bool = false,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption2.bold())
                .foregroundStyle(disabled ? Color.white.opacity(0.26) : .white)
                .frame(width: 24, height: 24)
                .background(accent ? SuiteColorTokens.mangaAccent : Color.white.opacity(disabled ? 0.04 : 0.11))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
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

    private func layerRow(index: Int, item: CelLayerRowItem) -> some View {
        let selected = item.id == selectedLayerId
        let canMoveUp = index < layers.count - 1
        let canMoveDown = index > 0

        return HStack(spacing: 6) {
            // Visibility eye toggle
            Button {
                guard layers.indices.contains(index) else { return }
                layers[index].visible.toggle()
                onUpdateLayer(layers[index])
            } label: {
                Image(systemName: item.visible ? "eye.fill" : "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(item.visible ? Color.white.opacity(0.88) : Color.white.opacity(0.32))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("Toggle layer visibility")

            // Layer selection & info area
            Button {
                selectedLayerId = item.id
            } label: {
                HStack(spacing: 6) {
                    // Stack level index badge (#1 bottom .. #N top)
                    Text("#\(index + 1)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(selected ? .white : Color.white.opacity(0.55))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(selected ? SuiteColorTokens.mangaAccent.opacity(0.65) : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .fixedSize()

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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Touch-friendly side-by-side Up (▲) and Down (▼) stack reorder buttons for iPad Pro
            HStack(spacing: 3) {
                Button {
                    selectedLayerId = item.id
                    onMoveLayer(item.id, true)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canMoveUp ? .white : Color.white.opacity(0.22))
                        .frame(width: 24, height: 26)
                        .background(canMoveUp ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .help("上移图层 (Move Layer Up)")

                Button {
                    selectedLayerId = item.id
                    onMoveLayer(item.id, false)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canMoveDown ? .white : Color.white.opacity(0.22))
                        .frame(width: 24, height: 26)
                        .background(canMoveDown ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .help("下移图层 (Move Layer Down)")
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
        .contextMenu {
            Button {
                selectedLayerId = item.id
                onMoveLayer(item.id, true)
            } label: {
                Label("上移一层 (Move Up)", systemImage: "arrow.up")
            }
            .disabled(!canMoveUp)

            Button {
                selectedLayerId = item.id
                onMoveLayer(item.id, false)
            } label: {
                Label("下移一层 (Move Down)", systemImage: "arrow.down")
            }
            .disabled(!canMoveDown)

            Divider()

            Button {
                selectedLayerId = item.id
                onDuplicateLayer()
            } label: {
                Label("复制图层 (Duplicate)", systemImage: "plus.square.on.square")
            }

            Button {
                selectedLayerId = item.id
                onClearLayer()
            } label: {
                Label("清空图层 (Clear)", systemImage: "eraser")
            }

            Button(role: .destructive) {
                selectedLayerId = item.id
                onDeleteLayer()
            } label: {
                Label("删除图层 (Delete)", systemImage: "trash")
            }
        }
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
