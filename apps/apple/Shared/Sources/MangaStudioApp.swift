#if canImport(SwiftUI)
import SwiftUI

/// Unified SwiftUI `@main` entry point shared across Wave 1 Apple targets
/// (`MangaStudio-iPadOS`, `MangaStudio-macOS-Touch`, `MangaStudio-iPhoneDuo`).
@main
struct MangaStudioApp: App {
    private var defaultPlatform: TargetPlatformKind {
        #if os(macOS)
        return .macOsTouch
        #else
        return .ipadOs
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppleWorkspaceShellView(
                initialState: AppleWorkspaceState(
                    platform: defaultPlatform,
                    posture: .flat,
                    mode: .mangaStudio,
                    activeSuiteApp: .manga
                )
            )
            #if os(macOS)
            .frame(minWidth: 960, minHeight: 620)
            #endif
        }
    }
}
#endif
