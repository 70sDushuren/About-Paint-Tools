#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Unified SwiftUI `@main` entry point shared across Wave 1 Apple targets
/// (`MangaStudio-iPadOS`, `MangaStudio-macOS-Touch`, `MangaStudio-iPhoneDuo`).
/// Wires `StudioWorkspaceController`, context-aware `StudioMenuCommands`, and
/// crash-safe lifecycle auto-flush on background & app quit (`v1.0.0-rc2`).
@main
struct MangaStudioApp: App {
    @StateObject private var controller = StudioWorkspaceController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppleWorkspaceShellView(controller: controller)
                #if os(macOS)
                .frame(minWidth: 980, minHeight: 640)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    controller.flushAllSync()
                }
                #endif
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        controller.flushAllSync()
                    }
                }
        }
        .commands {
            StudioMenuCommands(controller: controller)
        }
    }
}
#endif
