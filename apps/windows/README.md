# Touchscreen Windows Notebook / 2-in-1 Pad Native Shell (`apps/windows`)

**Target Milestone**: `v1.2` (Wave 2 — Post-`v1.0` Cross-Ecosystem Expansion)  
**Architecture**: WinUI 3 (Windows App SDK) + DirectX 12 `SwapChainPanel` (`wgpu` DX12 backend) + `WM_POINTER` / Windows Ink (`PointerPointProperties`) + Rust `manga_core.dll` (`cdylib` via P/Invoke).

## Modular Tri-App Entry Points (Working Codenames — Final Brand TBD before Release)
Three lightweight standalone-or-concurrent executables sharing `manga_core.dll` and one CPFF v1.0 `.prj` folder:
- **S1 — `创想空间` / `NoemaDock`** (`noemadock://`): Project overview, asset/prose import, Git/LFS & multi-language release hub
- **S2 — `雕龙` / `DracoNib`** (`draconib://`): Full DX12 + Windows Ink manga & illustration studio
- **S3 — `文心` / `LitteraCore`** (`litteracore://`): Lightweight novel writing & EPUB3/Markdown publisher (zero DX12 canvas overhead)

## Target Hardware
- Surface Pro / Surface Laptop Studio / Windows 2-in-1 Convertible Touch Notebooks (`x86_64` & `ARM64`)
- Pen-display & touch-enabled Windows tablets supporting MPP / Wacom AES / USI 2.0
- Automatic switch between **Desktop + Touch Hybrid** (keyboard attached) and **Tablet Touch Studio** (360° convertible tablet mode)

## Building Rust `manga_core.dll` on Windows
```powershell
# Build x86_64 or ARM64 Windows DLL from core/manga-core
cargo build --manifest-path ..\..\core\Cargo.toml -p manga-core --release
# Output: core\target\release\manga_core.dll
```
