---
order_id: 20261127-060652_v100-rc2-menus-layout-persistence
milestone: v1.0.0-rc2
status: FAIL
host: Shawns-M5MacPro.local
os: Darwin 27.2.0 arm64
git_sha: 9b4fd63
started_utc: 2026-11-27T06:07:34Z
finished_utc: 2026-11-27T06:07:41Z
duration_sec: 7
---

# GoNext Result: `20261127-060652_v100-rc2-menus-layout-persistence` — **FAIL**

- **Order**: [`20261127-060652_v100-rc2-menus-layout-persistence.json`](../orders/20261127-060652_v100-rc2-menus-layout-persistence.json)
- **Title**: Verify v1.0.0-rc2 Phase 1 (Context-Aware Menus + Zero-Overlap UI + MNGA0002 & Full Cold-Restart Restore, 39 XCTests)
- **Host**: `Shawns-M5MacPro.local` (`Darwin 27.2.0 arm64`) @ `9b4fd63`
- **Duration**: 7s (2026-11-27T06:07:34Z → 2026-11-27T06:07:41Z)

## Step Summary

| # | Action | Status | Duration | Exit Code |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `env-info` | **PASS** | 1s | 0 |
| 2 | `build-rust` | **PASS** | 4s | 0 |
| 3 | `xcode-gen` | **PASS** | 0s | 0 |
| 4 | `build-mac` | **FAIL** | 2s | 65 |
| 5 | `test-mac` | SKIPPED | 0s | - |
| 6 | `build-ipad` | SKIPPED | 0s | - |
| 7 | `build-duo` | SKIPPED | 0s | - |
| 8 | `check` | SKIPPED | 0s | - |

## Step Logs (Trimmed)

<details>
<summary>Step 1: <code>env-info</code> — PASS (exit=0, 1s)</summary>

```text
Host      : Shawns-M5MacPro.local
OS        : Darwin 27.2.0 arm64
macOS     : 27.2.1 (26B131)
Chip      : Apple M5 Pro
Xcode     : Xcode 27.2 Build version 27B52 
XcodeGen  : Version: 2.49.0
Rust      : rustc 1.100.0 (0ef1bc386 2026-11-09)
Cargo     : cargo 1.100.0 (3acc79c0c 2026-11-05)
Git HEAD  : 9b4fd63 (main)
```
</details>

<details>
<summary>Step 2: <code>build-rust</code> — PASS (exit=0, 4s)</summary>

```text
==> Rebuilding 3-slice MangaCore.xcframework...
==> [1/4] Building manga-core for iOS / iPadOS Device (aarch64-apple-ios)
   Compiling manga-core v0.1.0 (/Users/shawnhuang/About-paint-tools/core/manga-core)
    Finished `release` profile [optimized] target(s) in 1.48s
==> [2/4] Building manga-core for Apple Silicon iOS / iPadOS Simulator (aarch64-apple-ios-sim)
   Compiling manga-core v0.1.0 (/Users/shawnhuang/About-paint-tools/core/manga-core)
    Finished `release` profile [optimized] target(s) in 1.12s
==> [3/4] Building manga-core for Apple Silicon macOS (aarch64-apple-darwin)
   Compiling manga-core v0.1.0 (/Users/shawnhuang/About-paint-tools/core/manga-core)
    Finished `release` profile [optimized] target(s) in 1.14s
==> [4/4] Packaging /Users/shawnhuang/About-paint-tools/apps/apple/Frameworks/MangaCore.xcframework
xcframework successfully written out to: /Users/shawnhuang/About-paint-tools/apps/apple/Frameworks/MangaCore.xcframework
OK: Built /Users/shawnhuang/About-paint-tools/apps/apple/Frameworks/MangaCore.xcframework (iOS Device + iOS Simulator + macOS Apple Silicon)
==> Saved incremental build stamp: /Users/shawnhuang/About-paint-tools/apps/apple/.xcframework.stamp
```
</details>

<details>
<summary>Step 3: <code>xcode-gen</code> — PASS (exit=0, 0s)</summary>

```text
==> Generating /Users/shawnhuang/About-paint-tools/apps/apple/MangaStudioApple.xcodeproj from apps/apple/project.yml...
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/shawnhuang/About-Paint-Tools/apps/apple/MangaStudioApple.xcodeproj
```
</details>

<details>
<summary>Step 4: <code>build-mac</code> — FAIL (exit=65, 2s)</summary>

```text
SwiftDriver MangaStudio-macOS-Touch normal arm64 com.apple.xcode.tools.swift.compiler (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftDriver -- /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc -module-name MangaStudio_macOS_Touch -Onone @/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio-macOS-Touch.SwiftFileList -DDEBUG -enable-experimental-feature DebugDescriptionMacro -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk -target arm64-apple-macos15.0 -g -module-cache-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/ModuleCache.noindex -Xfrontend -serialize-debugging-options -enable-testing -index-store-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Index.noindex/DataStore -Xcc -D_LIBCPP_HARDENING_MODE\=_LIBCPP_HARDENING_MODE_DEBUG -swift-version 6 -I /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -F /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -F Frameworks -c -j18 -enable-batch-mode -incremental -Xcc -ivfsstatcache -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKStatCaches.noindex/macosx27.2-26B118-9aa026f88bf9ed31cff8761912ac5bd1a7ff82d74745d5ef33555b35c4238456.sdkstatcache -output-file-map /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio-macOS-Touch-OutputFileMap.json -save-temps -no-color-diagnostics -explicit-module-build -module-cache-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -clang-scanner-module-cache-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/ModuleCache.noindex -sdk-module-cache-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKExplicitPrecompiledModules -emit-dependencies -emit-module -emit-module-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio_macOS_Touch.swiftmodule -serialize-diagnostics -dependency-scan-serialize-diagnostics-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio_macOS_Touch-dependency-scan.dia -validate-clang-modules-once -clang-build-session-file /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -fmodules-prune-interval\=86400 -Xcc -fmodules-prune-after\=345600 -emit-const-values -const-gather-protocols-list /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio-macOS-Touch_const_extract_protocols.json -Xcc -iquote -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-generated-files.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-own-target-headers.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-all-target-headers.hmap -Xcc -iquote -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-project-headers.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/include -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources-normal/arm64 -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources/arm64 -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources -Xcc -DDEBUG\=1 -emit-objc-header -emit-objc-header-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio_macOS_Touch-Swift.h -working-directory /Users/shawnhuang/About-Paint-Tools/apps/apple -experimental-emit-module-separately -disable-cmo

Ld /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/MacOS/__preview.dylib normal (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang -Xlinker -reproducible -target arm64-apple-macos15.0 -dynamiclib -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk -O0 -Xlinker -no_warn_duplicate_libraries -L/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -F/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -FFrameworks -install_name @rpath/MangaStudio-macOS-Touch.debug.dylib -rdynamic -Xlinker -no_deduplicate -Xlinker -dependency_info -Xlinker /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio-macOS-Touch_dependency_info.dat -o /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/MacOS/__preview.dylib

SwiftExplicitDependencyGeneratePcm arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules/MangaCoreFFI-9MWGRQSRI3A22GIBZBL00SC6E.pcm

SwiftCompile normal arm64 Compiling\ HubWorkspaceView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/HubWorkspaceView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/HubWorkspaceView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile HubWorkspaceView.swift

SwiftCompile normal arm64 Compiling\ StudioMenuCommands.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioMenuCommands.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioMenuCommands.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile StudioMenuCommands.swift

SwiftCompile normal arm64 Compiling\ AppleWorkspaceShell.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/AppleWorkspaceShell.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/AppleWorkspaceShell.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile AppleWorkspaceShell.swift

SwiftCompile normal arm64 Compiling\ MangaCanvasStageView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCanvasStageView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCanvasStageView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile MangaCanvasStageView.swift

SwiftCompile normal arm64 Compiling\ StudioWorkspaceController.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioWorkspaceController.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioWorkspaceController.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile StudioWorkspaceController.swift

SwiftCompile normal arm64 Compiling\ CelLayerDrawerView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/CelLayerDrawerView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/CelLayerDrawerView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile CelLayerDrawerView.swift

SwiftCompile normal arm64 Compiling\ MacTouchInputAdapter.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/macOS-Touch/MacTouchInputAdapter.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/macOS-Touch/MacTouchInputAdapter.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile MacTouchInputAdapter.swift

SwiftCompile normal arm64 Compiling\ SuiteDesignSystem.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/SuiteDesignSystem.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/SuiteDesignSystem.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile SuiteDesignSystem.swift

SwiftEmitModule normal arm64 Emitting\ module\ for\ MangaStudio_macOS_Touch (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    

SwiftCompile normal arm64 Compiling\ NovelStudioView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
/Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift:378:48: error: cannot find '$theme' in scope
376 |                     .buttonStyle(.plain)
377 |                 } else {
378 |                     Picker("Theme", selection: $theme) {
    |                                                `- error: cannot find '$theme' in scope
379 |                         ForEach(PaperThemeKind.allCases) { item in
380 |                             Text(item.rawValue).tag(item)

/Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift:378:21: error: generic parameter 'SelectionValue' could not be inferred
376 |                     .buttonStyle(.plain)
377 |                 } else {
378 |                     Picker("Theme", selection: $theme) {
    |                     |- error: generic parameter 'SelectionValue' could not be inferred
    |                     `- note: explicitly specify the generic arguments to fix this issue
379 |                         ForEach(PaperThemeKind.allCases) { item in
380 |                             Text(item.rawValue).tag(item)
Failed frontend command:
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend -frontend -c /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/AppleWorkspaceShell.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/CelLayerDrawerView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/HubWorkspaceView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/macOS-Touch/MacTouchInputAdapter.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCanvasStageView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCoreBridge.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaStudioApp.swift -primary-file /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioMenuCommands.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/StudioWorkspaceController.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/SuiteDesignSystem.swift -emit-dependencies-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.d -emit-const-values-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.swiftconstvalues -emit-reference-dependencies-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.swiftdeps -serialize-diagnostics-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.dia -target arm64-apple-macos15.0 -module-can-import-version AppKit 2775.20.133 2775.20.133 -module-can-import MangaCoreFFI -module-can-import-version SwiftUI 8.1.13.1 8.1.13 -disable-cross-import-overlay-search -load-resolved-plugin /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libFoundationMacros.dylib\#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server\#FoundationMacros -load-resolved-plugin /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libObservationMacros.dylib\#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server\#ObservationMacros -load-resolved-plugin /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libPreviewsMacros.dylib\#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server\#PreviewsMacros -load-resolved-plugin /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftMacros.dylib\#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server\#SwiftMacros -load-resolved-plugin /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib\#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server\#SwiftUIMacros -disable-implicit-swift-modules -Xcc -fno-implicit-modules -Xcc -fno-implicit-module-maps -explicit-swift-module-map-file /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio_macOS_Touch-dependencies-1.json -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk -I /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -F /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug -F /Users/shawnhuang/About-Paint-Tools/apps/apple/Frameworks -module-cache-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format\=dwarf -dwarf-version\=5 -swift-version 6 -Onone -D DEBUG -serialize-debugging-options -enable-experimental-feature DebugDescriptionMacro -empty-abi-descriptor -validate-clang-modules-once -clang-build-session-file /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/ModuleCache.noindex/Session.modulevalidation -Xcc -working-directory -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple -enable-anonymous-context-mangled-names -file-compilation-dir /Users/shawnhuang/About-Paint-Tools/apps/apple -Xcc -D_LIBCPP_HARDENING_MODE\=_LIBCPP_HARDENING_MODE_DEBUG -Xcc -ivfsstatcache -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKStatCaches.noindex/macosx27.2-26B118-9aa026f88bf9ed31cff8761912ac5bd1a7ff82d74745d5ef33555b35c4238456.sdkstatcache -Xcc -fmodules-prune-interval\=86400 -Xcc -fmodules-prune-after\=345600 -Xcc -iquote -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-generated-files.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-own-target-headers.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-all-target-headers.hmap -Xcc -iquote -Xcc /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/MangaStudio-macOS-Touch-project-headers.hmap -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/include -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources-normal/arm64 -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources/arm64 -Xcc -I/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/DerivedSources -Xcc -DDEBUG\=1 -no-auto-bridging-header-chaining -module-name MangaStudio_macOS_Touch -const-gather-protocols-file /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio-macOS-Touch_const_extract_protocols.json -disable-clang-spi -clang-target arm64-apple-macos27.2 -target-sdk-version 27.2 -target-sdk-name macosx27.2 -in-process-plugin-server-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -o /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.o -debug-module-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/MangaStudio_macOS_Touch.swiftmodule -index-unit-output-path /MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Objects-normal/arm64/NovelStudioView.o -index-store-path /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Index.noindex/DataStore -index-system-modules

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile NovelStudioView.swift

SwiftCompile normal arm64 Compiling\ MangaStudioApp.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaStudioApp.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaStudioApp.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile MangaStudioApp.swift

SwiftCompile normal arm64 Compiling\ MangaCoreBridge.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCoreBridge.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/MangaCoreBridge.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-SwiftPerFileCompile MangaCoreBridge.swift

SwiftDriverJobDiscovery normal arm64 Compiling MacTouchInputAdapter.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftDriverJobDiscovery normal arm64 Compiling MangaStudioApp.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

SwiftDriverJobDiscovery normal arm64 Compiling SuiteDesignSystem.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules

** BUILD FAILED **


The following build commands failed:
	SwiftCompile normal arm64 Compiling\ NovelStudioView.swift /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
	SwiftCompile normal arm64 /Users/shawnhuang/About-Paint-Tools/apps/apple/Shared/Sources/NovelStudioView.swift (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
	Building project MangaStudioApple with scheme MangaStudio-macOS-Touch and configuration Debug
(3 failures)
```
</details>

