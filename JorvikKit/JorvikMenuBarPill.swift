import AppKit
import SwiftUI

/// Builds menu-bar icons, optionally with an always-visible grey background pill.
/// Composes pill + glyph into a single NSImage via a drawing handler so colours
/// re-evaluate on every paint, automatically tracking light/dark appearance —
/// the same pattern ActiveSpace uses.
enum JorvikMenuBarPill {

    /// Draws a glyph into `rect` using the supplied colour. The colour is supplied
    /// by the pill composer (so it can contrast with the pill background) or, when
    /// the pill is off, is whatever AppKit later tints a template image with.
    typealias GlyphDrawer = (_ rect: NSRect, _ color: NSColor) -> Void

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
            let sizedGlyph = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
            return composedPillIcon(
                glyphSize: sizedGlyph.size,
                drawGlyph: { rect, color in
                    let tinted = symbol.withSymbolConfiguration(
                        symbolConfig.applying(NSImage.SymbolConfiguration(paletteColors: [color, color]))
                    ) ?? sizedGlyph
                    let drawn = tinted.size
                    let gx = rect.minX + (rect.width  - drawn.width)  / 2
                    let gy = rect.minY + (rect.height - drawn.height) / 2
                    tinted.draw(at: NSPoint(x: gx, y: gy), from: .zero, operation: .sourceOver, fraction: 1.0)
                },
                tint: tint
            )
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

    /// Produces a status-bar icon for a custom-drawn glyph. The closure is called
    /// each time the image needs to render, with a rect of size `glyphSize` (and a
    /// suitable origin: zero when the pill is off, centred inside the pill when on).
    ///
    /// When the pill is off and no `tint` is set, the image is marked as a template
    /// so AppKit applies system tinting — design glyphs as monochrome filled shapes
    /// using the supplied `color` for that to work cleanly.
    static func icon(
        drawGlyph: @escaping GlyphDrawer,
        glyphSize: NSSize,
        tint: NSColor? = nil
    ) -> NSImage {
        if isEnabled {
            return composedPillIcon(glyphSize: glyphSize, drawGlyph: drawGlyph, tint: tint)
        }

        let image = NSImage(size: glyphSize, flipped: false) { rect in
            drawGlyph(rect, tint ?? .black)
            return true
        }
        image.isTemplate = (tint == nil)
        return image
    }

    private static func composedPillIcon(
        glyphSize: NSSize,
        drawGlyph: @escaping GlyphDrawer,
        tint: NSColor?
    ) -> NSImage {
        let hPad: CGFloat = 6
        let vPad: CGFloat = 2
        // Cap height to the menu bar's drawable region so the pill can't be clipped
        // top/bottom when the bar's effective thickness shrinks after a display
        // reconfiguration (e.g. moving from a notched display to an external one).
        let maxHeight = NSStatusBar.system.thickness - 2
        let size = NSSize(
            width:  max(22, glyphSize.width + hPad * 2),
            height: min(glyphSize.height + vPad * 2, maxHeight)
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

            // Centre the glyph rect inside the pill and let the caller draw into it.
            let gx = (rect.width  - glyphSize.width)  / 2
            let gy = (rect.height - glyphSize.height) / 2
            drawGlyph(
                NSRect(origin: NSPoint(x: gx, y: gy), size: glyphSize),
                glyphColor
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
