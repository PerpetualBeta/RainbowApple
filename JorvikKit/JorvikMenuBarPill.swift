import AppKit
import SwiftUI

/// Adds a configurable background pill behind an NSStatusBarButton.
/// Handles light/dark mode transitions automatically.
enum JorvikMenuBarPill {

    private static let pillLayerName = "jorvikPill"

    /// Applies or removes the pill background on a status bar button.
    /// Call this on launch and whenever settings change.
    static func apply(to button: NSStatusBarButton) {
        let enabled = UserDefaults.standard.bool(forKey: "menuBarPillEnabled")

        // Remove existing pill layer
        button.wantsLayer = true
        button.layer?.sublayers?.removeAll { $0.name == pillLayerName }

        guard enabled else { return }

        let pill = CALayer()
        pill.name = pillLayerName
        pill.cornerRadius = 4
        pill.masksToBounds = true

        updatePillColor(pill)

        // Insert behind content
        button.layer?.insertSublayer(pill, at: 0)

        // Size to button
        pill.frame = button.bounds.insetBy(dx: 1, dy: 2)

        // Observe frame changes
        pill.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }

    /// Updates pill colour based on stored preference and current appearance.
    static func updatePillColor(_ layer: CALayer) {
        let data = UserDefaults.standard.data(forKey: "menuBarPillColor")
        let baseColor: NSColor
        if let data, let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            baseColor = archived
        } else {
            baseColor = NSColor.controlAccentColor
        }

        // Adapt opacity for current appearance
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let opacity: Float = isDark ? 0.35 : 0.25

        layer.backgroundColor = baseColor.cgColor
        layer.opacity = opacity
    }

    /// Refreshes the pill on the given button (call on appearance change).
    static func refresh(on button: NSStatusBarButton) {
        guard let pill = button.layer?.sublayers?.first(where: { $0.name == pillLayerName }) else { return }
        updatePillColor(pill)
        pill.frame = button.bounds.insetBy(dx: 1, dy: 2)
    }

    /// Stores the pill colour preference.
    static func saveColor(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "menuBarPillColor")
        }
    }

    /// Reads the stored pill colour.
    static func loadColor() -> Color {
        guard let data = UserDefaults.standard.data(forKey: "menuBarPillColor"),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else { return Color.accentColor }
        return Color(nsColor: nsColor)
    }
}

/// SwiftUI settings section for the menu bar pill. Drop into JorvikSettingsView's appSettings closure.
struct MenuBarPillSettings: View {
    @State private var enabled = UserDefaults.standard.bool(forKey: "menuBarPillEnabled")
    @State private var pillColor: Color = JorvikMenuBarPill.loadColor()
    var onChanged: (() -> Void)?

    var body: some View {
        Section("Menu Bar Icon") {
            Toggle("Show background pill", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "menuBarPillEnabled")
                    onChanged?()
                }

            if enabled {
                ColorPicker("Pill colour", selection: $pillColor, supportsOpacity: false)
                    .onChange(of: pillColor) { _, newValue in
                        JorvikMenuBarPill.saveColor(NSColor(newValue))
                        onChanged?()
                    }
            }
        }
    }
}
