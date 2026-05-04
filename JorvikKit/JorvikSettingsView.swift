import SwiftUI
import ServiceManagement

struct JorvikSettingsView<AppSettings: View>: View {
    let appName: String
    @Bindable var updateChecker: JorvikUpdateChecker
    @ViewBuilder let appSettings: () -> AppSettings

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            Text("\(appName) Settings")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Form {
                // App-specific settings first (if any)
                appSettings()

                Section("General") {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                launchAtLogin = SMAppService.mainApp.status == .enabled
                            }
                        }
                }

                // Legacy Updates section removed during Sparkle 2.x migration.
                // Sparkle owns checking, downloading, and installation via
                // its own user-facing prompt; manual triggering lives on
                // the right-click menu's "Check for Updates…" entry.
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 420, height: 400)
    }

    static func showWindow(appName: String, updateChecker: JorvikUpdateChecker, @ViewBuilder appSettings: @escaping () -> AppSettings) {
        if let window = JorvikSettingsWindowCache.existingWindow {
            // If the cached window is hidden, bring it to the active space so
            // the user isn't yanked to wherever it was last shown. If it's
            // still visible on another space, leave default behavior — macOS
            // will switch to that space, which is what the user expects when
            // a window of theirs is already open elsewhere.
            if !window.isVisible {
                window.collectionBehavior.insert(.moveToActiveSpace)
                window.makeKeyAndOrderFront(nil)
                DispatchQueue.main.async {
                    window.collectionBehavior.remove(.moveToActiveSpace)
                }
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = JorvikSettingsView(
            appName: appName,
            updateChecker: updateChecker,
            appSettings: appSettings
        )
        let controller = NSHostingController(rootView: view)
        // Let the hosting controller compute its preferred size
        controller.view.layoutSubtreeIfNeeded()
        let fittingSize = controller.view.fittingSize
        let size = NSSize(width: max(fittingSize.width, 420), height: max(fittingSize.height, 400))

        let window = NSWindow(contentViewController: controller)
        window.title = "\(appName) Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        JorvikWindowHelper.centreOnActiveDisplay(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        JorvikSettingsWindowCache.existingWindow = window
    }
}

/// Non-generic cache for the settings window instance. `JorvikSettingsView`
/// is generic over the app-specific settings type, and Swift doesn't allow
/// static stored properties inside generic types — so the cache sits here.
private enum JorvikSettingsWindowCache {
    static var existingWindow: NSWindow?
}
