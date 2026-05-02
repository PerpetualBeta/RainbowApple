import Cocoa
import CoreText
import SwiftUI
import ServiceManagement
import ApplicationServices

// MARK: - Rainbow Apple Logo View

class RainbowAppleView: NSView {
    /// Scale factor for the rainbow fill — 8% bigger than the system Apple
    /// glyph so sub-pixel edges don't bleed through.
    static let rainbowScale: CGFloat = 1.08
    /// Scale factor for the backdrop mask — only fractionally bigger than
    /// the rainbow. The backdrop exists to cover sub-pixel grey bleed from
    /// the system Apple beneath; its opaque core should sit almost entirely
    /// under the rainbow so no visible backdrop-coloured ring shows.
    static let backdropScale: CGFloat = 1.08

    var fontSize: CGFloat = 22

    override var isFlipped: Bool { false }

    /// Build the centred Apple glyph path at a given scale. Returns nil if
    /// font lookup or path creation fails.
    static func applePath(in bounds: NSRect, fontSize: CGFloat, scale: CGFloat) -> CGPath? {
        let appleChar = "\u{F8FF}"
        let ctFont = CTFontCreateWithName("SFPro-Regular" as CFString, fontSize, nil)
        var unichars = [UniChar](appleChar.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &unichars, &glyphs, unichars.count) else { return nil }
        guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyphs[0], nil) else { return nil }

        let glyphBBox = glyphPath.boundingBox
        let tx = (bounds.width - glyphBBox.width) / 2 - glyphBBox.origin.x
        let ty = (bounds.height - glyphBBox.height) / 2 - glyphBBox.origin.y
        let cx = bounds.width / 2
        let cy = bounds.height / 2
        var transform = CGAffineTransform.identity
            .translatedBy(x: cx, y: cy)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -cx, y: -cy)
            .translatedBy(x: tx, y: ty)
        return glyphPath.copy(using: &transform)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let centredPath = Self.applePath(in: bounds, fontSize: fontSize, scale: Self.rainbowScale) else { return }
        let pathBounds = centredPath.boundingBox

        context.saveGState()
        context.addPath(centredPath)
        context.clip()

        // Original Apple rainbow logo — 6 solid horizontal stripes drawn as rectangles
        let stripeColors: [(CGFloat, CGFloat, CGFloat)] = [
            (0x61/255.0, 0xBB/255.0, 0x46/255.0),  // Green  #61BB46
            (0xFD/255.0, 0xB8/255.0, 0x27/255.0),  // Yellow #FDB827
            (0xF5/255.0, 0x82/255.0, 0x1F/255.0),  // Orange #F5821F
            (0xE0/255.0, 0x3A/255.0, 0x3E/255.0),  // Red    #E03A3E
            (0x96/255.0, 0x3D/255.0, 0x97/255.0),  // Purple #963D97
            (0x00/255.0, 0x9D/255.0, 0xDC/255.0),  // Blue   #009DDC
        ]

        let stripeHeight = pathBounds.height / CGFloat(stripeColors.count)
        for (i, color) in stripeColors.enumerated() {
            let y = pathBounds.maxY - stripeHeight * CGFloat(i + 1)
            let rect = CGRect(x: pathBounds.minX, y: y, width: pathBounds.width, height: stripeHeight)
            context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1.0)
            context.fill(rect)
        }

        context.restoreGState()
    }
}

// MARK: - Menu-bar-matching backdrop, masked to an Apple-shaped halo

/// Visual-effect backdrop that masks itself to a slightly-enlarged Apple
/// glyph shape with a feathered outer edge, so the backdrop fades into
/// the menu-bar background rather than reading as a defined halo ring.
final class MenuBarBackdrop: NSVisualEffectView {
    var fontSize: CGFloat = 22 {
        didSet {
            cachedMaskImage = nil
            cachedMaskKey = nil
            needsLayout = true
        }
    }

    private struct MaskKey: Equatable {
        let size: CGSize
        let fontSize: CGFloat
        let backingScale: CGFloat
    }
    private var cachedMaskImage: CGImage?
    private var cachedMaskKey: MaskKey?

    override func layout() {
        super.layout()
        wantsLayer = true
        guard let layer = self.layer else { return }
        guard let basePath = RainbowAppleView.applePath(
            in: bounds,
            fontSize: fontSize,
            scale: RainbowAppleView.backdropScale
        ) else {
            layer.mask = nil
            return
        }
        // Dilate by unioning the path with a stroked outline of itself.
        // Uniform scaling alone doesn't grow thin features (stem, leaf)
        // enough in absolute pixel terms; this adds material perpendicular
        // to every edge, which is exactly what thin features need.
        let dilationWidth: CGFloat = 0.5
        let strokedOutline = basePath.copy(
            strokingWithWidth: dilationWidth,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )
        let expanded = CGMutablePath()
        expanded.addPath(basePath)
        expanded.addPath(strokedOutline)

        let backingScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0
        let key = MaskKey(size: bounds.size, fontSize: fontSize, backingScale: backingScale)

        let maskImage: CGImage
        if let cached = cachedMaskImage, cachedMaskKey == key {
            maskImage = cached
        } else if let generated = Self.makeFeatheredMask(
            path: expanded,
            size: bounds.size,
            backingScale: backingScale,
            featherRadius: bounds.height * 0.20
        ) {
            cachedMaskImage = generated
            cachedMaskKey = key
            maskImage = generated
        } else {
            layer.mask = nil
            return
        }

        let mask = CALayer()
        mask.frame = bounds
        mask.contents = maskImage
        mask.contentsScale = backingScale
        layer.mask = mask
    }

    /// Render the dilated apple path to an alpha-mask CGImage with a soft
    /// outer feather. Pass 1 fills the path opaque (hard core over the
    /// system Apple); pass 2 strokes it with a shadow applied, which lays
    /// down a feathered band of partial alpha just outside the core.
    private static func makeFeatheredMask(
        path: CGPath,
        size: CGSize,
        backingScale: CGFloat,
        featherRadius: CGFloat
    ) -> CGImage? {
        let pixelWidth = Int((size.width * backingScale).rounded())
        let pixelHeight = Int((size.height * backingScale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: backingScale, y: backingScale)

        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

        // Pass 1 — opaque core.
        context.setFillColor(white)
        context.addPath(path)
        context.fillPath()

        // Pass 2 — shadowed stroke, producing the feathered outer band.
        context.setShadow(offset: .zero, blur: featherRadius, color: white)
        context.setStrokeColor(white)
        context.setLineWidth(0.5)
        context.addPath(path)
        context.strokePath()

        return context.makeImage()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    var statusItem: NSStatusItem!
    var positionSource: DispatchSourceTimer?
    var lastAXFrame: NSRect?
    var missionControlActive = false
    let updateChecker = JorvikUpdateChecker(repoName: "RainbowApple")

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyPillColorKey()

        // Prompt for Accessibility permission if not already granted
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        createOverlayWindow()
        positionOverlay()
        createStatusItem()
        updateChecker.checkOnSchedule()

        // Immediate response to known events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionOverlay),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(repositionOverlay),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(repositionOverlay),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // GCD timer fires independently of the main run loop's mode,
        // so it isn't stalled by space-transition animations the way
        // NSTimer is. Dispatches to main for the actual UI work.
        let source = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        source.schedule(deadline: .now(), repeating: .milliseconds(100))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let mc = Self.isMissionControlActive()
            DispatchQueue.main.async {
                if mc && !self.missionControlActive {
                    self.missionControlActive = true
                    self.overlayWindow.orderOut(nil)
                } else if !mc && self.missionControlActive {
                    self.missionControlActive = false
                    self.positionOverlay()
                } else if !mc {
                    self.positionOverlay()
                }
            }
        }
        source.resume()
        positionSource = source

    }

    // One-shot removal of the user-chosen pill colour key from the old design.
    // The new pill uses fixed grey/light colours; the key is dead weight.
    private func migrateLegacyPillColorKey() {
        let migrated = "didMigratePillColorV2"
        if UserDefaults.standard.bool(forKey: migrated) { return }
        UserDefaults.standard.removeObject(forKey: "menuBarPillColor")
        UserDefaults.standard.set(true, forKey: migrated)
    }

    func applyPill() {
        statusItem.button?.image = JorvikMenuBarPill.icon(
            symbolName: "apple.logo",
            accessibilityDescription: "RainbowApple"
        )
    }

    func createOverlayWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 20, height: 20),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        // Use a menu-bar-matching visual effect backdrop so the overlay is
        // opaque where the rainbow doesn't reach — the underlying system
        // Apple logo is hidden by the backdrop rather than bleeding through.
        let bounds = NSRect(x: 0, y: 0, width: 20, height: 20)
        let backdrop = MenuBarBackdrop(frame: bounds)
        backdrop.material = .titlebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.autoresizingMask = [.width, .height]

        let rainbow = RainbowAppleView(frame: bounds)
        rainbow.autoresizingMask = [.width, .height]
        backdrop.addSubview(rainbow)

        window.contentView = backdrop
        window.orderFrontRegardless()

        overlayWindow = window
    }

    // MARK: - Accessibility API positioning

    /// Query the Accessibility API for the exact frame of the Apple menu bar item.
    /// Returns the frame in AppKit screen coordinates (bottom-left origin), or nil
    /// if Accessibility is unavailable.
    func queryAppleMenuFrame() -> NSRect? {
        guard AXIsProcessTrusted() else { return nil }

        // Try the frontmost app first; fall back to Finder (always running)
        // if no app has focus — e.g. after a synthetic space switch.
        var menuBarRef: AnyObject?
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let el = AXUIElementCreateApplication(frontApp.processIdentifier)
            AXUIElementCopyAttributeValue(el, kAXMenuBarAttribute as CFString, &menuBarRef)
        }
        if menuBarRef == nil {
            let finder = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.finder" }
            if let pid = finder?.processIdentifier {
                let el = AXUIElementCreateApplication(pid)
                AXUIElementCopyAttributeValue(el, kAXMenuBarAttribute as CFString, &menuBarRef)
            }
        }
        guard let menuBar = menuBarRef else { return nil }

        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef) == .success else { return nil }

        guard let children = childrenRef as? [AXUIElement], let appleItem = children.first else { return nil }

        var posRef: AnyObject?
        var sizeRef: AnyObject?
        guard AXUIElementCopyAttributeValue(appleItem, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(appleItem, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // AX coordinates: origin at top-left of primary display, Y increases downward.
        // AppKit coordinates: origin at bottom-left of primary display, Y increases upward.
        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let nsY = primaryScreen.frame.height - point.y - size.height

        return NSRect(x: point.x, y: nsY, width: size.width, height: size.height)
    }

    func positionOverlay() {
        guard !missionControlActive else { return }

        let frame: NSRect
        if let axFrame = queryAppleMenuFrame() {
            lastAXFrame = axFrame
            frame = axFrame
        } else if let cached = lastAXFrame {
            frame = cached
        } else {
            positionOverlayMathematical()
            overlayWindow.orderFrontRegardless()
            return
        }

        // Only move the window when the frame has actually changed —
        // avoids visual artefacts from transient AX values mid-animation.
        let current = overlayWindow.frame
        if abs(current.origin.x - frame.origin.x) > 0.5
            || abs(current.origin.y - frame.origin.y) > 0.5
            || abs(current.width - frame.width) > 0.5
            || abs(current.height - frame.height) > 0.5 {
            overlayWindow.setFrame(frame, display: true)
            if let view = rainbowView {
                let size = frame.height * 0.80
                view.fontSize = size
                view.needsDisplay = true
                backdropView?.fontSize = size
            }
        }

        overlayWindow.orderFrontRegardless()
    }

    func positionOverlayMathematical() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        guard menuBarHeight > 0 else { return }

        let scale = menuBarHeight / 22.0
        let overlaySide: CGFloat = 20 * scale
        let appleCentreX: CGFloat = 28.5 * scale
        let verticalNudge: CGFloat = 1.5 * scale

        let x = screenFrame.origin.x + appleCentreX - overlaySide / 2
        let y = screenFrame.origin.y + screenFrame.height - menuBarHeight
              + (menuBarHeight - overlaySide) / 2 + verticalNudge

        overlayWindow.setFrame(
            NSRect(x: x, y: y, width: overlaySide, height: overlaySide),
            display: true
        )

        if let view = rainbowView {
            let size = 22 * scale
            view.fontSize = size
            view.needsDisplay = true
            backdropView?.fontSize = size
        }
    }

    /// The RainbowAppleView inside the visual-effect backdrop.
    private var rainbowView: RainbowAppleView? {
        overlayWindow.contentView?.subviews.compactMap { $0 as? RainbowAppleView }.first
    }

    /// The masked visual-effect backdrop (also the window's contentView).
    private var backdropView: MenuBarBackdrop? {
        overlayWindow.contentView as? MenuBarBackdrop
    }

    @objc func repositionOverlay() {
        positionOverlay()
    }

    /// Detect Mission Control by checking for Dock-owned windows at layer 18,
    /// which only appear while Mission Control is open.
    private static func isMissionControlActive() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains { w in
            (w["kCGWindowOwnerName"] as? String) == "Dock" && (w["kCGWindowLayer"] as? Int) == 18
        }
    }

    @objc func openAbout() {
        JorvikAboutView.showWindow(
            appName: "RainbowApple",
            repoName: "RainbowApple",
            productPage: "utilities/rainbowapple"
        )
    }

    @objc func openSettings() {
        JorvikSettingsView.showWindow(
            appName: "RainbowApple",
            updateChecker: updateChecker
        ) { [weak self] in
            RainbowAppleSettingsContent(onPillChanged: { self?.applyPill() })
        }
    }

    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        statusItem.menu = JorvikMenuBuilder.buildMenu(
            appName: "RainbowApple",
            aboutAction: #selector(openAbout),
            settingsAction: #selector(openSettings),
            target: self
        )

        applyPill()
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
