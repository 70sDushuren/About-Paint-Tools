# Touchscreen Linux Notebook / Pad Native Shell (`apps/linux`)

**Target Milestone**: `v1.3` (Wave 2 — Post-`v1.0` Cross-Ecosystem Expansion)  
**Architecture**: Native Rust (`GTK4` + `libadwaita` + Wayland `zwp_tablet_v2` / `libinput` + `wgpu` Vulkan) linking directly against `manga-core` with **zero FFI marshaling overhead**.

## Target Hardware
- 2-in-1 Touchscreen Linux Notebooks (ThinkPad X1 Yoga, Framework 12, Surface Linux)
- Wayland Linux Tablets & Large-Screen Handhelds (SteamOS / GNOME / KDE Plasma Touch)
- Wacom / EMR / USI 2.0 / MPP styluses via Wayland `zwp_tablet_v2`

## Why Rust + GTK4 / Wayland
1. **Zero FFI Overhead**: Direct Cargo workspace dependency on [`manga-core`](../../core/manga-core/Cargo.toml).
2. **MIT License Compliance**: Dynamic linking against system `libgtk-4` / `libadwaita` (LGPL) preserves our strict MIT license.
3. **Native Wayland Stylus & CJK IME**: Full support for `zwp_tablet_v2` tilt/pressure/barrel-roll/eraser-end, `libinput` palm rejection, fractional HiDPI scaling, and fcitx5/IBus CJK + Spanish input for the Light Novel Engine.
4. **Packaging**: Flatpak (Flathub) + AppImage.

## Tri-App Modular Launch & S4 Integration Gate
All three standalone-or-concurrent tools (working codenames TBD before release) run directly over CPFF v1.0 `.prj` folders:
- `--app hub` (Working Codename: `创想空间` / `NoemaDock` — `< 200 MB` RAM, no GPU canvas)
- `--app manga` (Working Codename: `雕龙` / `DracoNib` — full GPU canvas & tile pool)
- `--app novel` (Working Codename: `文心` / `LitteraCore` — `< 120 MB` RAM, no GPU canvas)

## Local & CI Verification (Zero External Dependencies in Foundation)
```bash
# Run unit tests (included in root Cargo workspace)
cargo test --manifest-path core/Cargo.toml -p manga-linux-shell

# Run headless Wayland tablet & 2-in-1 posture self-check
cargo run --manifest-path core/Cargo.toml -p manga-linux-shell -- --app manga --self-check

# Run S4 Tri-App Integration & Compatibility Gate on SampleManga
cargo run --manifest-path core/Cargo.toml -p manga-linux-shell -- --integration-check
```
