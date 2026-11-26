---
order_id: 20261126-092107_v022-apple-xctest-live-ffi
milestone: v0.2.2
status: PASS
host: Shawns-M5MacPro.local
os: Darwin 27.2.0 arm64
git_sha: 7fa92ad
started_utc: 2026-11-26T09:21:38Z
finished_utc: 2026-11-26T09:21:46Z
duration_sec: 8
---

# GoNext Result: `20261126-092107_v022-apple-xctest-live-ffi` — **PASS**

- **Order**: [`20261126-092107_v022-apple-xctest-live-ffi.json`](../orders/20261126-092107_v022-apple-xctest-live-ffi.json)
- **Title**: Run live macOS Swift XCTests over Rust MangaCoreFFI + all 3 Wave 1 Apple builds (v0.2.2)
- **Host**: `Shawns-M5MacPro.local` (`Darwin 27.2.0 arm64`) @ `7fa92ad`
- **Duration**: 8s (2026-11-26T09:21:38Z → 2026-11-26T09:21:46Z)

## Step Summary

| # | Action | Status | Duration | Exit Code |
| :--- | :--- | :--- | :--- | :--- |
| 1 | `env-info` | **PASS** | 1s | 0 |
| 2 | `build-rust` | **PASS** | 0s | 0 |
| 3 | `xcode-gen` | **PASS** | 0s | 0 |
| 4 | `build-mac` | **PASS** | 1s | 0 |
| 5 | `test-mac` | **PASS** | 4s | 0 |
| 6 | `build-ipad` | **PASS** | 0s | 0 |
| 7 | `build-duo` | **PASS** | 1s | 0 |
| 8 | `check` | **PASS** | 1s | 0 |

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
Git HEAD  : 7fa92ad (main)
```
</details>

<details>
<summary>Step 2: <code>build-rust</code> — PASS (exit=0, 0s)</summary>

```text
==> Rust core unchanged — skipping MangaCore.xcframework rebuild (pass --force to rebuild).
```
</details>

<details>
<summary>Step 3: <code>xcode-gen</code> — PASS (exit=0, 0s)</summary>

```text
==> Generating /Users/shawnhuang/About-Paint-Tools/apps/apple/MangaStudioApple.xcodeproj from apps/apple/project.yml...
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/shawnhuang/About-Paint-Tools/apps/apple/MangaStudioApple.xcodeproj
```
</details>

<details>
<summary>Step 4: <code>build-mac</code> — PASS (exit=0, 1s)</summary>

```text
    export __DIAGNOSE_INVALID_DEPLOYMENT_TARGET_AS_ERROR\=YES
    export __IS_NOT_MACOS\=NO
    export __IS_NOT_MACOS_macosx\=NO
    export __IS_NOT_SIMULATOR\=YES
    export __IS_NOT_SIMULATOR_simulator\=NO
    export __ORIGINAL_SDK_DEFINED_LLVM_TARGET_TRIPLE_SYS\=macos
    export arch\=undefined_arch
    export variant\=normal
    /bin/sh -c /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/Script-CADEA18A7A2DE4FE36C9B8FB.sh
==> Rust core unchanged — skipping MangaCore.xcframework rebuild (pass --force to rebuild).

ProcessInfoPlistFile /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Info.plist /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/empty-MangaStudio-macOS-Touch.plist (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-infoPlistUtility /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/empty-MangaStudio-macOS-Touch.plist -producttype com.apple.product-type.application -genpkginfo /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/PkgInfo -expandbuildsettings -platform macosx -o /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Info.plist

CopySwiftLibs /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/MacOS/MangaStudio-macOS-Touch.debug.dylib --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Frameworks --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/PlugIns --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Library/SystemExtensions --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Extensions --platform macosx --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v27.2.47.0.PHDdTp/Metal.xctoolchain --toolchain /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug/MangaStudio-macOS-Touch.app/Contents/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug/MangaStudio-macOS-Touch.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

note: Disabling hardened runtime with ad-hoc codesigning. (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
note: Run script build phase 'Sync Rust MangaCore XCFramework (Incremental)' will be run during every build because the option to run the script phase "Based on dependency analysis" is unchecked. (in target 'MangaStudio-macOS-Touch' from project 'MangaStudioApple')
** BUILD SUCCEEDED **

```
</details>

<details>
<summary>Step 5: <code>test-mac</code> — PASS (exit=0, 4s)</summary>

```text
Please file a bug at https://feedbackassistant.apple.com with this warning message and any useful information you can provide.
Test Suite 'All tests' started at 2026-11-26 03:21:43.646.
Test Suite 'MangaStudio-macOS-Tests.xctest' started at 2026-11-26 03:21:43.646.
Test Suite 'MangaStudioV022Tests' started at 2026-11-26 03:21:43.646.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testDesignSystemIconAndThemeCatalogIntegrity]' started.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testDesignSystemIconAndThemeCatalogIntegrity]' passed (0.001 seconds).
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS1HubBootstrapsCanonicalCpffProjectOnDisk]' started.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS1HubBootstrapsCanonicalCpffProjectOnDisk]' passed (0.006 seconds).
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS2BrushDynamicsAndSparseTileUndoRedoLifecycle]' started.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS2BrushDynamicsAndSparseTileUndoRedoLifecycle]' passed (0.001 seconds).
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS3NovelMixedCjkAndLatinWordCounting]' started.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testS3NovelMixedCjkAndLatinWordCounting]' passed (0.000 seconds).
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testTriAppRamBudgetsAndWriteOwnershipIsolation]' started.
Test Case '-[MangaStudio_macOS_Tests.MangaStudioV022Tests testTriAppRamBudgetsAndWriteOwnershipIsolation]' passed (0.000 seconds).
Test Suite 'MangaStudioV022Tests' passed at 2026-11-26 03:21:43.655.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Suite 'MangaStudio-macOS-Tests.xctest' passed at 2026-11-26 03:21:43.655.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.008 (0.009) seconds
Test Suite 'All tests' passed at 2026-11-26 03:21:43.655.
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.008 (0.010) seconds
2026-11-26 03:21:43.936 xcodebuild[16310:5382350] [MT] IDETestOperationsObserverDebug: 1.049 elapsed -- Testing started completed.
2026-11-26 03:21:43.936 xcodebuild[16310:5382350] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-11-26 03:21:43.936 xcodebuild[16310:5382350] [MT] IDETestOperationsObserverDebug: 1.049 sec, +1.049 sec -- end

Test session results, code coverage, and logs:
	/Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Logs/Test/Test-MangaStudio-macOS-Touch-2026.11.26_03-21-41--0600.xcresult

** TEST SUCCEEDED **

Testing started
```
</details>

<details>
<summary>Step 6: <code>build-ipad</code> — PASS (exit=0, 0s)</summary>

```text
    export __DIAGNOSE_DEPRECATED_ARCHS\=YES
    export __DIAGNOSE_INVALID_DEPLOYMENT_TARGET_AS_ERROR\=YES
    export __IS_NOT_MACOS\=YES
    export __IS_NOT_MACOS_macosx\=NO
    export __IS_NOT_SIMULATOR\=NO
    export __IS_NOT_SIMULATOR_simulator\=NO
    export __ORIGINAL_SDK_DEFINED_LLVM_TARGET_TRIPLE_SYS\=ios
    export arch\=undefined_arch
    export variant\=normal
    /bin/sh -c /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPadOS.build/Script-52796D43E29753E8D28E2601.sh
==> Rust core unchanged — skipping MangaCore.xcframework rebuild (pass --force to rebuild).

ProcessInfoPlistFile /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/Info.plist /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPadOS.build/empty-MangaStudio-iPadOS.plist (in target 'MangaStudio-iPadOS' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-infoPlistUtility /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPadOS.build/empty-MangaStudio-iPadOS.plist -producttype com.apple.product-type.application -genpkginfo /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/PkgInfo -expandbuildsettings -format binary -platform iphonesimulator -o /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/Info.plist

CopySwiftLibs /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app (in target 'MangaStudio-iPadOS' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/MangaStudio-iPadOS.debug.dylib --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/Frameworks --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/PlugIns --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/SystemExtensions --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/Extensions --platform iphonesimulator --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v27.2.47.0.PHDdTp/Metal.xctoolchain --toolchain /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPadOS.app/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPadOS.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

note: Run script build phase 'Sync Rust MangaCore XCFramework (Incremental)' will be run during every build because the option to run the script phase "Based on dependency analysis" is unchecked. (in target 'MangaStudio-iPadOS' from project 'MangaStudioApple')
** BUILD SUCCEEDED **

```
</details>

<details>
<summary>Step 7: <code>build-duo</code> — PASS (exit=0, 1s)</summary>

```text
    export __DIAGNOSE_DEPRECATED_ARCHS\=YES
    export __DIAGNOSE_INVALID_DEPLOYMENT_TARGET_AS_ERROR\=YES
    export __IS_NOT_MACOS\=YES
    export __IS_NOT_MACOS_macosx\=NO
    export __IS_NOT_SIMULATOR\=NO
    export __IS_NOT_SIMULATOR_simulator\=NO
    export __ORIGINAL_SDK_DEFINED_LLVM_TARGET_TRIPLE_SYS\=ios
    export arch\=undefined_arch
    export variant\=normal
    /bin/sh -c /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPhoneDuo.build/Script-9B94D855C27D26F2F8A07D3E.sh
==> Rust core unchanged — skipping MangaCore.xcframework rebuild (pass --force to rebuild).

ProcessInfoPlistFile /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/Info.plist /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPhoneDuo.build/empty-MangaStudio-iPhoneDuo.plist (in target 'MangaStudio-iPhoneDuo' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-infoPlistUtility /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPhoneDuo.build/empty-MangaStudio-iPhoneDuo.plist -producttype com.apple.product-type.application -genpkginfo /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/PkgInfo -expandbuildsettings -format binary -platform iphonesimulator -o /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/Info.plist

CopySwiftLibs /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app (in target 'MangaStudio-iPhoneDuo' from project 'MangaStudioApple')
    cd /Users/shawnhuang/About-Paint-Tools/apps/apple
    builtin-swiftStdLibTool --copy --verbose --scan-executable /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/MangaStudio-iPhoneDuo.debug.dylib --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/Frameworks --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/PlugIns --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/SystemExtensions --scan-folder /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/Extensions --platform iphonesimulator --toolchain /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v27.2.47.0.PHDdTp/Metal.xctoolchain --toolchain /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain --destination /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Products/Debug-iphonesimulator/MangaStudio-iPhoneDuo.app/Frameworks --strip-bitcode --strip-bitcode-tool /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/bitcode_strip --emit-dependency-info /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/MangaStudioApple.build/Debug-iphonesimulator/MangaStudio-iPhoneDuo.build/SwiftStdLibToolInputDependencies.dep --filter-for-swift-os --back-deploy-swift-span
Ignoring --strip-bitcode because --sign was not passed

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/SDKExplicitPrecompiledModules

PruneExplicitPrecompiledModules /Users/shawnhuang/About-Paint-Tools/apps/apple/DerivedData/Build/Intermediates.noindex/ExplicitPrecompiledModules

note: Run script build phase 'Sync Rust MangaCore XCFramework (Incremental)' will be run during every build because the option to run the script phase "Based on dependency analysis" is unchecked. (in target 'MangaStudio-iPhoneDuo' from project 'MangaStudioApple')
** BUILD SUCCEEDED **

```
</details>

<details>
<summary>Step 8: <code>check</code> — PASS (exit=0, 1s)</summary>

```text
test tests::linux_shell_switches_between_desktop_touch_and_2in1_tablet_mode ... ok

test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

     Running unittests src/main.rs (core/target/debug/build/manga-linux-shell/4fa36a6daedc5663/out/manga_linux_shell-4fa36a6daedc5663)

running 0 tests

test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
==> [7/7] Running Tri-App headless self-checks & S4 Integration Gate...
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `core/target/debug/manga-linux-shell --app hub --self-check`
manga-linux-shell [suite.hub / codename: 创想空间 / NoemaDock | GPU canvas=false | RAM budget=200MB] (Vulkan (wgpu)): desktop=DesktopTouchHybrid, 2in1_tablet=TabletTouchStudio, dirty_tiles=0
OK: Loaded CPFF v1.0 project 'SampleManga: Starlight Blade' (engines=dual-novel-manga, editions=4)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `core/target/debug/manga-linux-shell --app manga --self-check`
manga-linux-shell [suite.manga / codename: 雕龙 / DracoNib | GPU canvas=true | RAM budget=1536MB] (Vulkan (wgpu)): desktop=DesktopTouchHybrid, 2in1_tablet=TabletTouchStudio, dirty_tiles=1
OK: Loaded CPFF v1.0 project 'SampleManga: Starlight Blade' (engines=dual-novel-manga, editions=4)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `core/target/debug/manga-linux-shell --app novel --self-check`
manga-linux-shell [suite.novel / codename: 文心 / LitteraCore | GPU canvas=false | RAM budget=120MB] (Vulkan (wgpu)): desktop=DesktopTouchHybrid, 2in1_tablet=TabletTouchStudio, dirty_tiles=0
OK: Loaded CPFF v1.0 project 'SampleManga: Starlight Blade' (engines=dual-novel-manga, editions=4)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.00s
     Running `core/target/debug/manga-linux-shell --integration-check`
OK [S4 Integration Gate]: Tri-app compatibility verified on 'prj-sample-manga-001' (editions=4, chapters=1, write_isolation=true, ai_redline=true, deep_links=true, combined_ram_budget=1856MB)
OK: All About-Paint-Tools CI & S4 integration gates passed.
```
</details>

