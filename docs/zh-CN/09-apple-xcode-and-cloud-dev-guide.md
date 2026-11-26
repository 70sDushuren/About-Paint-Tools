# 09. Apple 平台 MacBook Pro 本地 Xcode 联动开发与 Xcode Cloud 评估指南

**语言 / Language**: [English](../en/09-apple-xcode-and-cloud-dev-guide.md) | **简体中文**

> **适用范围**：Wave 1 Apple 三端（**iPad · 触摸屏 MacBook · iPhone Duo**）与三独立工具（暂定代号：`S1 创想空间/NoemaDock`、`S2 雕龙/DracoNib`、`S3 文心/LitteraCore`）。

---

## 1. 基于现有成果的 MacBook Pro + Xcode 落地开发流程

### 1.1 仓库现有 Apple 底座
当前基线（`v0.1.0-architecture-baseline`）已在仓库中准备好完整的跨语言底座：
- Rust 核心引擎与三模块 Feature 裁剪：[`core/manga-core/Cargo.toml`](../../core/manga-core/Cargo.toml)
- 零警告 C11 FFI 头文件：[`core/manga-core/include/manga_core.h`](../../core/manga-core/include/manga_core.h)
- Swift RAII 桥接与 `SuiteAppKind`：[`apps/apple/Shared/Sources/MangaCoreBridge.swift`](../../apps/apple/Shared/Sources/MangaCoreBridge.swift)
- 三硬件 Target 工程描述：[`apps/apple/project.yml`](../../apps/apple/project.yml) 与 5 语言 [`Localizable.xcstrings`](../../apps/apple/Shared/Resources/Localizable.xcstrings)

### 1.2 核心升级：打包三切片 `MangaCore.xcframework`
为同时支持真机 iPad（`aarch64-apple-ios`）、Apple Silicon 模拟器（`aarch64-apple-ios-sim`）与 macOS 原生（`aarch64-apple-darwin`），建议在 MacBook Pro 上通过统一脚本构建 `XCFramework`：

```bash
cargo build --manifest-path core/Cargo.toml -p manga-core --release --target aarch64-apple-ios
cargo build --manifest-path core/Cargo.toml -p manga-core --release --target aarch64-apple-ios-sim
cargo build --manifest-path core/Cargo.toml -p manga-core --release --target aarch64-apple-darwin

xcodebuild -create-xcframework \
  -library core/target/aarch64-apple-ios/release/libmanga_core.a     -headers core/manga-core/include \
  -library core/target/aarch64-apple-ios-sim/release/libmanga_core.a -headers core/manga-core/include \
  -library core/target/aarch64-apple-darwin/release/libmanga_core.a  -headers core/manga-core/include \
  -output apps/apple/Frameworks/MangaCore.xcframework
```

### 1.3 Xcode 26+ 与跨语言 AI 辅助编程双层协同
1. **层 A（Xcode 26+ 原生 Coding Intelligence / 26.3+ Agentic Coding + MCP）**：专精 SwiftUI 界面还原、Metal 着色器调试、Swift 6 并发纠错与 5 语言实时 Canvas 预览。
2. **层 B（跨语言 AI 代理：Antigravity / Claude Code / Cursor + Xcode MCP）**：同步联动修改 `core/manga-core`（Rust）→ `manga_core.h` → `MangaCoreBridge.swift` → `i18n/locales/*.json`（同步 `.xcstrings`）并一键验证。
3. **真机与性能剖析**：通过 USB-C/无线连接真机 iPad Pro 实测 240Hz Apple Pencil Pro 延迟（目标 `≤ 9ms`），用 **Metal Frame Capture** 与 **Instruments（Allocations/Jetsam）** 验收 `S1 < 200 MB`、`S3 < 120 MB` 与 `S2` 8GB 连续绘制 2 小时零闪退。

---

## 2. MacBook Pro 硬件要求、工具链安装与云端开发环境衔接

### 2.1 硬件配置建议（需兼顾 Xcode + Rust + 本地 Gemma 4）

| 配置档位 | Apple Silicon 芯片 | 统一内存 | SSD | 适用说明 |
| :--- | :--- | :--- | :--- | :--- |
| **最低可用门槛** | M2 Pro / M3 | **24 GB** | **512 GB** | 满足单 Target + 模拟器 + Gemma 4 E2B 基础测试（避开 16GB 以下） |
| **推荐主力配置** | **M4 Pro**（12–14 核） | **36 GB / 48 GB** | **1 TB** | 流畅并发 Xcode + Rust + AI 代理 + 三工具同开 + **Gemma 4 E4B** 推理 |
| **理想旗舰配置** | M4 Max | **64 GB+** | **2 TB** | 适合 Wave 2 多端模拟与 `v1.1`–`v1.4` 视觉 AI（MobileSAM/LT/3D）调优 |

### 2.2 一键工具链安装清单
```bash
xcode-select --install && sudo xcodebuild -license accept
xcodebuild -downloadPlatform iOS
brew install git git-lfs gh xcodegen python3 jq
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin
git lfs install
git clone https://github.com/70sDushuren/About-Paint-Tools.git
```

### 2.3 与云端 Linux VM 开发环境的双向接力架构

```mermaid
flowchart LR
    Cloud["云端 Linux VM (架构 / Rust核心 / i18n / 文档 / Wave 2)"] <-->|"git push / pull"| GH["GitHub 唯一事实源 + GitHub Actions CI"]
    GH <-->|"git pull --rebase / PR"| Mac["本地 MacBook Pro (Xcode 26+ / Metal / Pencil Pro 真机)"]
    GH -->|"main / v* Tag 触发"| XC["Apple Xcode Cloud (25h/月免费) -> TestFlight / App Store"]
```

- **职责分工**：云端负责 Rust 平台无关内核、CPFF/i18n/双语文档与跨平台校验；MacBook Pro 负责 Metal 渲染、SwiftUI/UIKit/AppKit 原生交互与真机手感剖析。
- **防冲突原则**：`Localizable.xcstrings` 严禁仅在 Xcode 侧手改源词条，一律通过 `i18n/locales/*.json` + `scripts/i18n_sync.py --export-xcstrings --export-android` 单源同步。

---

## 3. Apple 云端开发环境（Xcode Cloud）评估与配置指南

### 3.1 可行性结论
- **概念厘清**：Apple 官方不提供“网页版远程 Mac 桌面 IDE”；Apple 官方云端服务是 **Xcode Cloud**（原生云端 CI/CD：构建、并行模拟器 XCTest、自动签名、公证、TestFlight 与 App Store 分发）。
- **成本与推荐架构**：**Apple Developer Program（\$99/年）免费赠送 25 计算小时/月**（超额 \$49.99/100h）。推荐 **「本地 MacBook Pro + GitHub Actions（全平台 Rust/i18n/Android/Win/Linux CI）+ Xcode Cloud（免费 25h/月专攻 Apple 自动签名与 TestFlight）」** 双云混合架构。

### 3.2 Xcode Cloud 接入本 Rust + XcodeGen 仓库的 4 步实操
1. **提交轻量 `.xcodeproj`**：运行 `cd apps/apple && xcodegen generate` 后将 `MangaStudioApple.xcodeproj`（排除 `xcuserdata/`）入库，确保 Xcode Cloud 可扫描 Scheme；将 `Frameworks/MangaCore.xcframework` 保持在 `.gitignore`。
2. **配置 `apps/apple/ci_scripts/ci_post_clone.sh`（`chmod +x`）**：在云端自动安装最小化 `rustup` + 3 个 Apple Targets，跑 `cargo test -p manga-core` 并组装 `MangaCore.xcframework`。
3. **配置 3 条 Workflow**（`Xcode → Integrate → Xcode Cloud → Create Workflow`）：
   - `Wave1-Beta-TestFlight`：`main` 或 `v0.9*-beta*` 触发 → 自动签名并分发至 TestFlight；
   - `Wave1-Release-Store`：通过 `S4` 门禁打标 `v1.0.*` → 全量 XCTest + App Store Connect 提审与 macOS 公证。
4. **预留语义化 Bundle ID 与共享 App Group**：
   - `org.aboutpainttools.suite.hub`（S1） / `org.aboutpainttools.suite.manga`（S2） / `org.aboutpainttools.suite.novel`（S3）
   - 共享 App Group：`group.org.aboutpainttools.shared`（跨工具共享 `.prj` 书签权限与单份本地 Gemma 4 离线模型权重缓存）。
