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
    /// - `rotation`: optional radians to rotate the glyph (pill stays horizontal,
    ///   glyph rotates inside). Used e.g. by Tugboat to match the system Dock position.
    static func icon(
        symbolName: String,
        pointSize: CGFloat = 15,
        weight: NSFont.Weight = .regular,
        tint: NSColor? = nil,
        rotation: CGFloat = 0,
        accessibilityDescription: String?
    ) -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        ) else { return nil }

        let symbolConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)

        if isEnabled {
            return composedPillIcon(symbol: symbol, symbolConfig: symbolConfig, tint: tint, rotation: rotation)
        }

        if let tint {
            let config = symbolConfig.applying(
                NSImage.SymbolConfiguration(paletteColors: [tint, tint])
            )
            let sized = symbol.withSymbolConfiguration(config) ?? symbol
            sized.isTemplate = false
            return rotation == 0 ? sized : rotated(sized, by: rotation, isTemplate: false)
        }

        let sized = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        sized.isTemplate = true
        return rotation == 0 ? sized : rotated(sized, by: rotation, isTemplate: true)
    }

    private static func composedPillIcon(
        symbol: NSImage,
        symbolConfig: NSImage.SymbolConfiguration,
        tint: NSColor?,
        rotation: CGFloat
    ) -> NSImage {
        // Measure the configured glyph so the pill wraps it with consistent padding.
        let sizedGlyph = symbol.withSymbolConfiguration(symbolConfig) ?? symbol
        let baseGlyphSize = sizedGlyph.size

        // A quarter-turn rotation swaps the glyph's effective width/height inside the pill.
        let isQuarterTurn = abs(abs(rotation).truncatingRemainder(dividingBy: .pi) - .pi / 2) < 0.001
        let glyphSize = isQuarterTurn
            ? NSSize(width: baseGlyphSize.height, height: baseGlyphSize.width)
            : baseGlyphSize

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

            let tinted = symbol.withSymbolConfiguration(
                symbolConfig.applying(NSImage.SymbolConfiguration(paletteColors: [glyphColor, glyphColor]))
            ) ?? sizedGlyph
            let drawn = tinted.size

            if rotation == 0 {
                let gx = (rect.width  - drawn.width)  / 2
                let gy = (rect.height - drawn.height) / 2
                tinted.draw(at: NSPoint(x: gx, y: gy), from: .zero, operation: .sourceOver, fraction: 1.0)
            } else if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.saveGState()
                ctx.translateBy(x: rect.width / 2, y: rect.height / 2)
                ctx.rotate(by: rotation)
                tinted.draw(
                    at: NSPoint(x: -drawn.width / 2, y: -drawn.height / 2),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0
                )
                ctx.restoreGState()
            }

            return true
        }
        image.isTemplate = false
        return image
    }

    /// Render `source` into a new image rotated by `radians` about its centre.
    /// For quarter-turn rotations the output dimensions swap so nothing is clipped.
    private static func rotated(_ source: NSImage, by radians: CGFloat, isTemplate: Bool) -> NSImage {
        let srcSize = source.size
        let isQuarterTurn = abs(abs(radians).truncatingRemainder(dividingBy: .pi) - .pi / 2) < 0.001
        let outSize = isQuarterTurn
            ? NSSize(width: srcSize.height, height: srcSize.width)
            : srcSize

        let image = NSImage(size: outSize, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: outSize.width / 2, y: outSize.height / 2)
            ctx.rotate(by: radians)
            source.draw(
                at: NSPoint(x: -srcSize.width / 2, y: -srcSize.height / 2),
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            return true
        }
        image.isTemplate = isTemplate
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
