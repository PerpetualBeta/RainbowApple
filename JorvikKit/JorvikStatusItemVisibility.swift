import AppKit
import SwiftUI

/// Lets a menu-bar app hide its status-bar item and get it back by
/// relaunching from /Applications — the standard "I closed the icon, how
/// do I get it back?" escape hatch.
///
/// The persisted state lives per-bundle in `UserDefaults`. Changing it
/// posts a local `didChangeNotification`; the app observes that and creates
/// or removes its own `NSStatusItem` (the helper deliberately doesn't own
/// the item, because each app builds its menu differently). This mirrors
/// `JorvikDockVisibility`'s decoupled, notification-driven shape and keeps
/// the type free of `@MainActor`/`Sendable` ceremony.
///
/// **Adoption** (AppDelegate, three small wires):
///
/// 1. Gate status-item creation on `isVisible`:
///    ```
///    func createStatusItem() {
///        guard JorvikStatusItemVisibility.isVisible else { return }
///        statusItem = NSStatusBar.system.statusItem(withLength: .squareLength)
///        // … build menu, set image …
///    }
///    ```
/// 2. Observe changes and apply them (in `applicationDidFinishLaunching`):
///    ```
///    NotificationCenter.default.addObserver(
///        forName: JorvikStatusItemVisibility.didChangeNotification,
///        object: nil, queue: .main
///    ) { [weak self] _ in self?.applyStatusItemVisibility() }
///    ```
///    where `applyStatusItemVisibility()` creates the item when
///    `isVisible` and `removeStatusItem` + nils it otherwise.
/// 3. Restore on relaunch:
///    ```
///    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
///        JorvikStatusItemVisibility.handleReopen()
///        return true
///    }
///    ```
///
/// For the settings UI, drop `MenuBarVisibilitySettings()` into your
/// `JorvikSettingsView` content.
public enum JorvikStatusItemVisibility {

    /// Posted (locally) whenever the visibility flag changes. The app
    /// observes this to create or remove its status item.
    public static let didChangeNotification = Notification.Name(
        "cc.jorviksoftware.JorvikKit.StatusItemVisibilityDidChange"
    )

    private static let defaultsPrefix = "JorvikStatusItemVisibility.Hidden."

    private static var key: String {
        defaultsPrefix + (Bundle.main.bundleIdentifier ?? "unknown")
    }

    /// Whether the app's status-bar item should currently be shown.
    /// Persisted per-bundle; defaults to `true` (visible) for fresh installs.
    public static var isVisible: Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    /// Persist a new visibility state and broadcast the change. Call from
    /// the settings toggle.
    public static func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        UserDefaults.standard.set(!visible, forKey: key)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    /// Restore a hidden status item. Call from
    /// `applicationShouldHandleReopen(_:hasVisibleWindows:)` — relaunching
    /// the app from /Applications is the user's only way back to a hidden
    /// icon, so this is the load-bearing escape hatch.
    public static func handleReopen() {
        setVisible(true)
    }
}

/// SwiftUI settings section for hiding the menu-bar status item. Drop into
/// `JorvikSettingsView`'s appSettings closure. Pairs naturally above
/// `MenuBarPillSettings` (icon on/off first, then its appearance).
///
/// **Version-gated to macOS < 26.** macOS 26 Tahoe added a native
/// "Allow in the Menu Bar" control in System Settings for third-party
/// items, so the in-app toggle would be redundant there — it's hidden on
/// Tahoe and shown only on Sonoma/Sequoia, where the OS offers no
/// equivalent. The underlying mechanism stays active on every version; the
/// persisted flag simply defaults to visible, so a Tahoe user who never
/// touched it just sees the icon and manages it the system way.
public struct MenuBarVisibilitySettings: View {
    @State private var showIcon = JorvikStatusItemVisibility.isVisible

    public init() {}

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "the app"
    }

    public var body: some View {
        // Defer to System Settings' native control on macOS 26+.
        if #unavailable(macOS 26.0) {
            Section("Menu Bar") {
                Toggle("Show icon in menu bar", isOn: $showIcon)
                    .onChange(of: showIcon) { _, newValue in
                        JorvikStatusItemVisibility.setVisible(newValue)
                    }
                if !showIcon {
                    Text("Re-open \(appName) from your Applications folder to bring the icon back.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
