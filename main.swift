import Cocoa
import CoreText
import SwiftUI
import ServiceManagement
import ApplicationServices
import Sparkle

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

    /// Split the glyph into the apple body (bite included) and the leaf. The 1977
    /// logo treats the two differently, so they can't be striped as one shape —
    /// see `draw(_:)`. Returns the whole path as the body if there's no separate
    /// leaf contour to find.
    static func split(_ path: CGPath) -> (body: CGPath, leaf: CGPath?) {
        var contours: [CGMutablePath] = []
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                let contour = CGMutablePath()
                contour.move(to: e.points[0])
                contours.append(contour)
            case .addLineToPoint:
                contours.last?.addLine(to: e.points[0])
            case .addQuadCurveToPoint:
                contours.last?.addQuadCurve(to: e.points[1], control: e.points[0])
            case .addCurveToPoint:
                contours.last?.addCurve(to: e.points[2], control1: e.points[0], control2: e.points[1])
            case .closeSubpath:
                contours.last?.closeSubpath()
            @unknown default:
                break
            }
        }

        let largest = contours.max { a, b in
            let (x, y) = (a.boundingBox, b.boundingBox)
            return x.width * x.height < y.width * y.height
        }
        guard contours.count > 1, let main = largest else { return (path, nil) }

        let body = CGMutablePath()
        let leaf = CGMutablePath()
        for contour in contours {
            // A contour rising above the apple itself is the leaf. Anything else —
            // the bite, if the font ever expresses it as its own contour — is body.
            if contour !== main, contour.boundingBox.maxY > main.boundingBox.maxY {
                leaf.addPath(contour)
            } else {
                body.addPath(contour)
            }
        }
        return (body, leaf.isEmpty ? nil : leaf)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let centredPath = Self.applePath(in: bounds, fontSize: fontSize, scale: Self.rainbowScale) else { return }
        let (body, leaf) = Self.split(centredPath)
        let bodyBounds = body.boundingBox

        // Original Apple rainbow logo — 6 solid horizontal stripes drawn as rectangles
        let stripeColors: [(CGFloat, CGFloat, CGFloat)] = [
            (0x61/255.0, 0xBB/255.0, 0x46/255.0),  // Green  #61BB46
            (0xFD/255.0, 0xB8/255.0, 0x27/255.0),  // Yellow #FDB827
            (0xF5/255.0, 0x82/255.0, 0x1F/255.0),  // Orange #F5821F
            (0xE0/255.0, 0x3A/255.0, 0x3E/255.0),  // Red    #E03A3E
            (0x96/255.0, 0x3D/255.0, 0x97/255.0),  // Purple #963D97
            (0x00/255.0, 0x9D/255.0, 0xDC/255.0),  // Blue   #009DDC
        ]

        // Each band is a sixth of the APPLE's height, not a sixth of the glyph's
        // overall bounding box. Measured off the 1977 original: body 116px tall in
        // six 19.33px bands, leaf solid green. Striping the combined body+leaf box
        // instead spends the whole green band on the leaf, leaves the leaf's own tip
        // yellow, and shifts every boundary up — the apple's shoulder comes out
        // yellow and only five colours land on the fruit.
        context.saveGState()
        context.addPath(body)
        context.clip()
        let stripeHeight = bodyBounds.height / CGFloat(stripeColors.count)
        for (i, color) in stripeColors.enumerated() {
            // Paint each band from its own top edge all the way down, top colour
            // first, so later bands overwrite earlier ones. Abutting rectangles
            // would meet on a fractional pixel and leave a hairline seam; with
            // this the only edges are inside already-painted area.
            let top = bodyBounds.maxY - stripeHeight * CGFloat(i)
            let rect = CGRect(x: bodyBounds.minX, y: bodyBounds.minY,
                              width: bodyBounds.width, height: top - bodyBounds.minY)
            context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1.0)
            context.fill(rect)
        }
        context.restoreGState()

        // The leaf carries the top band's green in full — it is never two-tone.
        if let leaf {
            context.saveGState()
            context.addPath(leaf)
            context.clip()
            let green = stripeColors[0]
            context.setFillColor(red: green.0, green: green.1, blue: green.2, alpha: 1.0)
            context.fill(leaf.boundingBox)
            context.restoreGState()
        }
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
    let sparkleUserDriverDelegate = RainbowAppleUserDriverDelegate()
    lazy var sparkleUpdater = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: sparkleUserDriverDelegate
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyPillColorKey()

        // Prompt for Accessibility permission if not already granted
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        createOverlayWindow()
        repositionOverlay()
        createStatusItem()
        _ = sparkleUpdater  // forces lazy init so Sparkle starts at launch

        // Immediate response to known events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionOverlay),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // Also redraw the status-item pill on display changes — the menu bar's
        // effective thickness can shrink (e.g. moving from a notched display
        // to an external one) and leave the pre-rendered pill cropped.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyPill()
        }
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

        // Add/remove the status-bar item when the user toggles its visibility
        // in Settings. The rainbow overlay is unaffected — this only governs
        // the right-side apple.logo item that opens the menu.
        NotificationCenter.default.addObserver(
            forName: JorvikStatusItemVisibility.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.applyStatusItemVisibility()
        }

        // GCD timer fires independently of the main run loop's mode,
        // so it isn't stalled by space-transition animations the way
        // NSTimer is. Dispatches to main for the actual UI work. One
        // window-list copy per tick feeds both the Mission Control check
        // and the menu-bar-visibility check.
        let source = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        source.schedule(deadline: .now(), repeating: .milliseconds(100))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let windows = Self.onScreenWindows()
            let mc = Self.isMissionControlActive(in: windows)
            let barRects = Self.menuBarWindowRects(in: windows)
            DispatchQueue.main.async {
                if mc && !self.missionControlActive {
                    self.missionControlActive = true
                    self.overlayWindow.orderOut(nil)
                } else if !mc && self.missionControlActive {
                    self.missionControlActive = false
                    self.positionOverlay(barRects: barRects)
                } else if !mc {
                    self.positionOverlay(barRects: barRects)
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
        statusItem?.button?.image = JorvikMenuBarPill.icon(
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

        // Not ordered front here — positionOverlay() shows it once there is a
        // sane frame to show it at. Ordering front at the creation rect put a
        // 20×20 window in the bottom-left corner whenever no position could
        // be determined (issue #2: launch while an auto-hidden bar is hidden).
        window.contentView = backdrop

        overlayWindow = window
    }

    // MARK: - Accessibility API positioning

    /// Query the Accessibility API for the exact frame of the Apple menu bar item.
    /// Returns the frame in AppKit screen coordinates (bottom-left origin), or nil
    /// if Accessibility is unavailable or every candidate reports an unusable frame.
    func queryAppleMenuFrame() -> NSRect? {
        guard AXIsProcessTrusted() else { return nil }

        // Ask the app that actually OWNS the drawn menu bar, not merely the one with
        // focus. An agent app (LSUIElement) never draws a menu bar, yet AppKit still
        // gives it a main menu — so its AX menu bar exists and reports the Apple item
        // at a phantom 0×0 frame. Trusting the frontmost app therefore collapsed the
        // overlay to nothing whenever an agent app with a focusable window took focus
        // (Ballast's visualiser being the obvious one). menuBarOwningApplication stays
        // on the real owner through exactly that transition.
        var candidates: [pid_t] = []
        if let owner = NSWorkspace.shared.menuBarOwningApplication {
            candidates.append(owner.processIdentifier)
        }
        if let front = NSWorkspace.shared.frontmostApplication, front.activationPolicy == .regular {
            candidates.append(front.processIdentifier)
        }
        // Finder is always running, and owns the bar when nothing else does —
        // e.g. after a synthetic space switch leaves no app with focus.
        if let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            candidates.append(finder.processIdentifier)
        }

        for pid in candidates {
            if let frame = appleMenuFrame(ofProcess: pid), isOnMenuBar(frame) { return frame }
        }
        return nil
    }

    /// The Apple menu item's frame as one app's AX menu bar reports it, converted to
    /// AppKit coordinates. Unvalidated — callers must run it past `isOnMenuBar`.
    private func appleMenuFrame(ofProcess pid: pid_t) -> NSRect? {
        var menuBarRef: AnyObject?
        let app = AXUIElementCreateApplication(pid)
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else { return nil }

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

    /// True when a candidate frame genuinely lands in the menu bar. The strip's
    /// thickness is read off each screen (frame minus visibleFrame), never assumed:
    /// it is 22pt on an external bar, 24pt on a notched panel, 31pt on macOS 26,
    /// and NSStatusBar.thickness disagrees with all of it.
    private func isOnMenuBar(_ frame: NSRect) -> Bool {
        guard !frame.isEmpty else { return false }

        let strips = NSScreen.screens.compactMap { screen -> NSRect? in
            let thickness = screen.frame.maxY - screen.visibleFrame.maxY
            guard thickness > 0 else { return nil }   // this screen isn't drawing a bar
            return NSRect(x: screen.frame.minX, y: screen.frame.maxY - thickness,
                          width: screen.frame.width, height: thickness)
        }

        // No screen reports a strip at all: the bar is set to auto-hide and is hidden
        // right now, so there is no thickness to measure. Fall back to the one thing
        // still true of a real Apple item — its top edge is flush with a screen's top.
        guard !strips.isEmpty else {
            return NSScreen.screens.contains { abs($0.frame.maxY - frame.maxY) < frame.height }
        }

        return strips.contains { $0.intersects(frame) }
    }

    /// One snapshot of the on-screen window list, shared by the Mission
    /// Control and menu-bar-visibility checks so each tick pays for it once.
    static func onScreenWindows() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    /// The menu bar's backing windows (one per screen drawing a bar), in
    /// AppKit coordinates. With "Automatically hide and show the menu bar"
    /// enabled, the window server removes them from the on-screen list while
    /// the bar is hidden — their presence is the one visibility signal that
    /// holds across every combination of setting and reveal state, and their
    /// bounds are the bar's true rect even when auto-hide makes the
    /// visibleFrame arithmetic read zero thickness. Matched by level and
    /// geometry only: window NAMES are empty without Screen Recording
    /// permission, and owner names localise ("Control Centre").
    static func menuBarWindowRects(in windows: [[String: Any]]) -> [NSRect] {
        guard let primary = NSScreen.screens.first else { return [] }
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        return windows.compactMap { w in
            guard (w["kCGWindowLayer"] as? Int) == menuLevel,
                  let boundsDict = w["kCGWindowBounds"] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: boundsDict) else { return nil }
            // CG coordinates: origin at top-left of the primary display,
            // Y increasing downward. Convert to AppKit (bottom-left origin).
            let rect = NSRect(x: cg.origin.x,
                              y: primary.frame.height - cg.origin.y - cg.height,
                              width: cg.width, height: cg.height)
            // A menu bar is flush with a screen's top and at least half as
            // wide as that screen — nothing else lives at this window level.
            let isBar = NSScreen.screens.contains { screen in
                abs(rect.maxY - screen.frame.maxY) < 1
                    && rect.width >= screen.frame.width * 0.5
            }
            return isBar ? rect : nil
        }
    }

    func positionOverlay(barRects: [NSRect]) {
        guard !missionControlActive else { return }

        // An overlay for a hidden bar must hide with it. Covers launching
        // while an auto-hidden bar is off screen, the hide after a hover
        // reveal (issue #2's "sticky" rainbow), and full-screen spaces.
        guard !barRects.isEmpty else {
            overlayWindow.orderOut(nil)
            return
        }

        let frame: NSRect
        if let axFrame = queryAppleMenuFrame() {
            lastAXFrame = axFrame
            frame = axFrame
        } else if let cached = lastAXFrame {
            frame = cached
        } else {
            // No AX frame and nothing cached: place mathematically off the
            // bar's measured rect, or stay hidden — a window with no sane
            // position must never be shown at whatever frame it happens to
            // already have.
            if positionOverlayMathematical(barRects: barRects) {
                overlayWindow.orderFrontRegardless()
            } else {
                overlayWindow.orderOut(nil)
            }
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

    /// Position off the bar's measured rect — the rect that exists even when
    /// auto-hide zeroes the frame-minus-visibleFrame thickness. Prefers the
    /// bar on the screen with keyboard focus. Returns false when no bar rect
    /// is available to position against.
    @discardableResult
    func positionOverlayMathematical(barRects: [NSRect]) -> Bool {
        let barRect: NSRect
        if let main = NSScreen.main, let onMain = barRects.first(where: { main.frame.intersects($0) }) {
            barRect = onMain
        } else if let first = barRects.first {
            barRect = first
        } else {
            return false
        }

        let scale = barRect.height / 22.0
        let overlaySide: CGFloat = 20 * scale
        // The Apple item's x-centre does NOT scale with bar height: measured
        // ≈28.5 on a 22pt external bar and ≈27 (AX: item x=10 w=34) on a 33pt
        // notched bar. Scaling it put the fallback overlay ~15pt right of the
        // real apple on notched panels. Only the vertical metrics scale.
        let appleCentreX: CGFloat = 28.5
        let verticalNudge: CGFloat = 1.5 * scale

        let x = barRect.minX + appleCentreX - overlaySide / 2
        let y = barRect.minY + (barRect.height - overlaySide) / 2 + verticalNudge

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
        return true
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
        positionOverlay(barRects: Self.menuBarWindowRects(in: Self.onScreenWindows()))
    }

    /// Detect Mission Control by checking for Dock-owned windows at layer 18,
    /// which only appear while Mission Control is open.
    private static func isMissionControlActive(in windows: [[String: Any]]) -> Bool {
        windows.contains { w in
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
        JorvikSettingsView.showWindow(appName: "RainbowApple") { [weak self] in
            RainbowAppleSettingsContent(onPillChanged: { self?.applyPill() })
        }
    }

    func createStatusItem() {
        // Honour the user's "Show icon in menu bar" choice. When hidden, the
        // rainbow overlay still runs; only this right-side item is suppressed,
        // and relaunching the app from /Applications brings it back.
        guard JorvikStatusItemVisibility.isVisible else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Persist the item's menu-bar slot across launches (and let a user ⌘-drag stick).
        statusItem.autosaveName = "RainbowAppleStatusItem"

        statusItem.menu = JorvikMenuBuilder.buildMenu(
            appName: "RainbowApple",
            aboutAction: #selector(openAbout),
            settingsAction: #selector(openSettings),
            target: self,
            actions: [
                JorvikMenuBuilder.ActionItem(
                    title: "Check for Updates\u{2026}",
                    action: #selector(checkForUpdates(_:)),
                    target: self
                )
            ]
        )

        applyPill()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        sparkleUpdater.checkForUpdates(sender)
    }

    /// Create or tear down the status-bar item to match the persisted
    /// visibility flag. Driven by the Settings toggle and by relaunch.
    func applyStatusItemVisibility() {
        if JorvikStatusItemVisibility.isVisible {
            if statusItem == nil { createStatusItem() }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Relaunching from /Applications is the way back to a hidden icon. A
    /// single-instance LSUIElement app routes the second launch here as a
    /// reopen rather than spawning a new process.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        JorvikStatusItemVisibility.handleReopen()
        return true
    }
}

/// Keeps Sparkle's update UI visible across the whole session, including
/// when the user switches to another app mid-download. See KB:
/// `conventions/sparkle-integration.md` §6 for the rationale.
final class RainbowAppleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    private var sessionObserver: NSObjectProtocol?
    private var elevatedWindows: [(window: NSWindow, originalLevel: NSWindow.Level)] = []

    func standardUserDriverWillShowModalAlert() {
        bringForward()
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        startFocusGuard()
        bringForward()
    }

    func standardUserDriverWillFinishUpdateSession() {
        stopFocusGuard()
    }

    private func bringForward() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        elevateAllWindows()
    }

    private func startFocusGuard() {
        guard sessionObserver == nil else { return }
        sessionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bringForward()
        }
    }

    private func stopFocusGuard() {
        if let obs = sessionObserver {
            NotificationCenter.default.removeObserver(obs)
            sessionObserver = nil
        }
        for entry in elevatedWindows {
            entry.window.level = entry.originalLevel
        }
        elevatedWindows.removeAll()
    }

    private func elevateAllWindows() {
        for window in NSApp.windows where window.isVisible && window.level == .normal {
            elevatedWindows.append((window, window.level))
            window.level = .floating
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
