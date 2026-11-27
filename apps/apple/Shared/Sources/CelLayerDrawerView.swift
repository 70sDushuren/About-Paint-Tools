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

/// `S2 v1.0-rc5` — ibisPaint-aligned Right Cel Layer Drawer with full CRUD, Custom Layer Renaming,
/// and Stack Reordering (Add / Rename / Duplicate / Move Up / Move Down / Merge Down / Delete / Clear) +
/// `R` Reference / `✂` Clipping / `🔒` Alpha Lock / `B` Blue Sketch + zero-overlap layout.
/// Moving a layer up or down never alters its custom name.
public struct CelLayerDrawerView: View {
    @Binding public var layers: [CelLayerRowItem]
    @Binding public var selectedLayerId: UInt64
    public let onAddLayer: () -> Void
    public let onDuplicateLayer: () -> Void
    public let onDeleteLayer: () -> Void
    public let onMergeDown: () -> Void
    public let onMoveLayer: (UInt64, Bool) -> Void
    public let onRenameLayer: (UInt64, String) -> Void
    public let onClearLayer: () -> Void
    public let onUpdateLayer: (CelLayerRowItem) -> Void

    @State private var renamingLayerId: UInt64? = nil
    @State private var renameDraftText: String = ""

    public init(
        layers: Binding<[CelLayerRowItem]>,
        selectedLayerId: Binding<UInt64>,
        onAddLayer: @escaping () -> Void,
        onDuplicateLayer: @escaping () -> Void = {},
        onDeleteLayer: @escaping () -> Void = {},
        onMergeDown: @escaping () -> Void = {},
        onMoveLayer: @escaping (UInt64, Bool) -> Void = { _, _ in },
        onRenameLayer: @escaping (UInt64, String) -> Void = { _, _ in },
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
        self.onRenameLayer = onRenameLayer
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

    private func beginRenaming(_ item: CelLayerRowItem) {
        selectedLayerId = item.id
        renamingLayerId = item.id
        renameDraftText = item.name
    }

    private func commitRename(for layerId: UInt64) {
        let trimmed = renameDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRenameLayer(layerId, trimmed)
            if let idx = layers.firstIndex(where: { $0.id == layerId }), layers[idx].name != trimmed {
                layers[idx].name = trimmed
            }
        }
        if renamingLayerId == layerId {
            renamingLayerId = nil
        }
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
                    iconActionButton(
                        symbol: "pencil",
                        help: "自定义重命名当前图层 Rename Layer",
                        disabled: selectedIndex == nil
                    ) {
                        if let idx = selectedIndex {
                            beginRenaming(layers[idx])
                        }
                    }
                    iconActionButton(symbol: "plus.square.on.square", help: "复制图层 Duplicate Layer (⌘J)", action: onDuplicateLayer)
                        .disabled(selectedIndex == nil)
                    iconActionButton(
                        symbol: "arrow.up",
                        help: "将选中图层上移一层 (名称保持不变)",
                        disabled: !canMoveSelectedUp
                    ) {
                        onMoveLayer(selectedLayerId, true)
                    }
                    iconActionButton(
                        symbol: "arrow.down",
                        help: "将选中图层下移一层 (名称保持不变)",
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
                        Text("图层列表 (点按铅笔图标可自定义名称)")
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
        let layerId = layer.id
        return VStack(alignment: .leading, spacing: 8) {
            // Custom Layer Name Quick Editor Bar
            if renamingLayerId == layerId {
                HStack(spacing: 6) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.caption2)
                        .foregroundStyle(SuiteColorTokens.hubAccent)
                    TextField("输入自定义图层名称", text: $renameDraftText)
                        .textFieldStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .onSubmit {
                            commitRename(for: layerId)
                        }
                    Button("确定") {
                        commitRename(for: layerId)
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SuiteColorTokens.mangaAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .buttonStyle(.plain)

                    Button {
                        renamingLayerId = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.white.opacity(0.65))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(SuiteColorTokens.hubAccent, lineWidth: 1)
                )
            } else {
                HStack(spacing: 6) {
                    Text(layer.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Button {
                        beginRenaming(layer)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .bold))
                            Text("重命名")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.10))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("修改当前图层名称")
                }
            }

            HStack(spacing: 8) {
                Picker("Blend", selection: Binding(
                    get: {
                        layers.first(where: { $0.id == layerId })?.blendMode ?? layer.blendMode
                    },
                    set: { newMode in
                        guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                        layers[i].blendMode = newMode
                        onUpdateLayer(layers[i])
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
                    get: {
                        layers.first(where: { $0.id == layerId })?.opacity ?? layer.opacity
                    },
                    set: { newOpacity in
                        guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                        layers[i].opacity = newOpacity
                        onUpdateLayer(layers[i])
                    }
                ), in: 0.0...1.0)
                .tint(SuiteColorTokens.mangaAccent)
            }

            // Quick Flags: R (Reference) / ✂ (Clip) / 🔒 (Alpha Lock) / B (Blue Sketch)
            HStack(spacing: 6) {
                flagToggle("R", active: layer.isReference) {
                    guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                    layers[i].isReference.toggle()
                    onUpdateLayer(layers[i])
                }
                flagToggle("✂", active: layer.clippingMask) {
                    guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                    layers[i].clippingMask.toggle()
                    onUpdateLayer(layers[i])
                }
                flagToggle("🔒", active: layer.alphaLock) {
                    guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                    layers[i].alphaLock.toggle()
                    onUpdateLayer(layers[i])
                }
                flagToggle("B", active: layer.blueSketchTint) {
                    guard let i = layers.firstIndex(where: { $0.id == layerId }) else { return }
                    layers[i].blueSketchTint.toggle()
                    onUpdateLayer(layers[i])
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
        let isEditingName = renamingLayerId == item.id

        return HStack(spacing: 6) {
            // Visibility eye toggle (looked up by stable item.id so reordering never hits a stale index)
            Button {
                guard let currentIdx = layers.firstIndex(where: { $0.id == item.id }) else { return }
                layers[currentIdx].visible.toggle()
                onUpdateLayer(layers[currentIdx])
            } label: {
                Image(systemName: item.visible ? "eye.fill" : "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(item.visible ? Color.white.opacity(0.88) : Color.white.opacity(0.32))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("Toggle layer visibility")

            // Layer selection & custom name area (no changing #index prefix in front of the layer name!)
            if isEditingName {
                HStack(spacing: 4) {
                    TextField("图层名称", text: $renameDraftText)
                        .textFieldStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .onSubmit {
                            commitRename(for: item.id)
                        }
                    Button {
                        commitRename(for: item.id)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(SuiteColorTokens.hubAccent)
                    }
                    .buttonStyle(.plain)
                }
            } else {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Inline 1-tap rename button + Up (▲) and Down (▼) stack reorder buttons
            HStack(spacing: 3) {
                Button {
                    beginRenaming(item)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .frame(width: 22, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("重命名图层 (Rename Layer)")

                Button {
                    selectedLayerId = item.id
                    onMoveLayer(item.id, true)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(canMoveUp ? .white : Color.white.opacity(0.22))
                        .frame(width: 22, height: 26)
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
                        .frame(width: 22, height: 26)
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
                beginRenaming(item)
            } label: {
                Label("重命名图层 (Rename)", systemImage: "pencil")
            }

            Divider()

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
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.14))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
#endif
