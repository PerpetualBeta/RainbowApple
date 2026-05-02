import AppKit
import SwiftUI

/// Builds menu-bar icons, optionally with an always-visible grey background pill.
/// Composes pill + symbol into a single NSImage via a drawing handler so colours
/// re-evaluate on every paint, automatically tracking light/dark appearance —
/// the same pattern ActiveSpace uses.
enum JorvikMenuBarPill {

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "menuBarPillEnabled")
    }

    /// Produces a status-bar icon for the given SF Symbol.
    /// - `tint`: optional palette colour baked into the symbol (used for alert states).
    ///   When `nil` and the pill is off, the symbol is returned as a template image
    ///   so AppKit handles system tinting. When `nil` and the pill is on, the symbol
    ///   is drawn in a contrast colour chosen against the pill background.
    static func icon(
        symbolName: String,
        pointSize: CGFloat = 15,
        weight: NSFont.Weight = .regular,
        tint: NSColor? = nil,
        accessibilityDescription: String?
    ) -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        ) else { return nil }

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)

        if isEnabled {
            return composedPillIcon(symbol: symbol, symbolConfig: symbolConfig, tint: tint)
        }

        if let tint {
            let config = symbolConfig.applying(
                NSImage.SymbolConfiguration(paletteColors: [tint, tint])
            )
            let sized = symbol.withSymbolConfiguration(config) ?? symbol
            sized.isTemplate = false
            return sized
        }

        let sized = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        sized.isTemplate = true
        return sized
    }

    private static func composedPillIcon(
        symbol: NSImage,
        symbolConfig: NSImage.SymbolConfiguration,
        tint: NSColor?
    ) -> NSImage {
        // Measure the configured glyph so the pill wraps it with consistent padding.
        let sizedGlyph = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        let glyphSize = sizedGlyph.size

        let hPad: CGFloat = 6
        let vPad: CGFloat = 2
        let size = NSSize(
            width:  max(22, glyphSize.width  + hPad * 2),
            height:       glyphSize.height + vPad * 2
        )

        let image = NSImage(size: size, flipped: false) { rect in
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            // Light mode: dark pill; dark mode: light pill. Alpha baked in — no layer.opacity.
            let pillColor: NSColor = isDark ? NSColor(white: 0.85, alpha: 1.0)
                                            : NSColor(white: 0.20, alpha: 0.85)

            // Default glyph colour contrasts with the pill; alert tints override.
            let defaultGlyphColor: NSColor = isDark ? NSColor(white: 0.10, alpha: 1.0) : .white
            let glyphColor = tint ?? defaultGlyphColor

            // Fill the pill.
            let path = NSBezierPath(
                roundedRect: rect,
                xRadius: rect.height / 2,
                yRadius: rect.height / 2
            )
            pillColor.setFill()
            path.fill()

            // Centre the tinted glyph on the pill.
            let tinted = symbol.withSymbolConfiguration(
                symbolConfig.applying(NSImage.SymbolConfiguration(paletteColors: [glyphColor, glyphColor]))
            ) ?? sizedGlyph
            let drawn = tinted.size
            let gx = (rect.width  - drawn.width)  / 2
            let gy = (rect.height - drawn.height) / 2
            tinted.draw(
                at: NSPoint(x: gx, y: gy),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )

            return true
        }
        image.isTemplate = false
        return image
    }
}

/// SwiftUI settings section for the menu bar pill. Drop into JorvikSettingsView's appSettings closure.
struct MenuBarPillSettings: View {
    @State private var enabled = JorvikMenuBarPill.isEnabled
    var onChanged: (() -> Void)?

    var body: some View {
        Section("Menu Bar Icon") {
            Toggle("Show background pill", isOn: $enabled)
                .onChange(of: enabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "menuBarPillEnabled")
                    onChanged?()
                }
        }
    }
}
