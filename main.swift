import Cocoa
import CoreText
import SwiftUI

// MARK: - Rainbow Apple Logo View

class RainbowAppleView: NSView {
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let appleChar = "\u{F8FF}"
        let fontSize: CGFloat = 22
        let ctFont = CTFontCreateWithName("SFPro-Regular" as CFString, fontSize, nil)

        // Get the glyph for the Apple logo character
        var unichars = [UniChar](appleChar.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
        guard CTFontGetGlyphsForCharacters(ctFont, &unichars, &glyphs, unichars.count) else { return }

        // Get the glyph path
        guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyphs[0], nil) else { return }

        // Centre the glyph in the view
        let glyphBBox = glyphPath.boundingBox
        let tx = (bounds.width - glyphBBox.width) / 2 - glyphBBox.origin.x
        let ty = (bounds.height - glyphBBox.height) / 2 - glyphBBox.origin.y
        var transform = CGAffineTransform(translationX: tx, y: ty)
        guard let centredPath = glyphPath.copy(using: &transform) else { return }

        // Get the ACTUAL bounding box of the centred glyph — gradient must span this, not the view
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
            // Stripes drawn top-to-bottom: green at top, blue at bottom
            // In non-flipped coords, top = maxY
            let y = pathBounds.maxY - stripeHeight * CGFloat(i + 1)
            let rect = CGRect(x: pathBounds.minX, y: y, width: pathBounds.width, height: stripeHeight)
            context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1.0)
            context.fill(rect)
        }

        context.restoreGState()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow!
    var statusItem: NSStatusItem!
    private var aboutPopover: NSPopover?
    private var aboutMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createOverlayWindow()
        positionOverlay()
        createStatusItem()

        // Observe screen parameter changes (resolution, display config)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func createOverlayWindow() {
        let w: CGFloat = 20
        let h: CGFloat = 20
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = RainbowAppleView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        window.orderFrontRegardless()

        overlayWindow = window
    }

    func positionOverlay() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        let size = overlayWindow.frame.size

        // Centre over the Apple menu icon
        // Measured: system icon centre is ~13.25pt from screen left in Retina coords
        // Empirical offset accounts for coordinate system differences
        let appleCentreX: CGFloat = 28.5
        let x = screenFrame.origin.x + appleCentreX - size.width / 2
        let y = screenFrame.origin.y + screenFrame.height - menuBarHeight + (menuBarHeight - size.height) / 2 + 1.5

        overlayWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc func screenChanged() {
        positionOverlay()
    }

    @objc func openAbout() {
        guard let button = statusItem.button else { return }
        let p = NSPopover()
        p.behavior = .applicationDefined
        p.animates = true
        let hc = NSHostingController(rootView: AboutView(appName: "RainbowApple", onDismiss: { [weak self] in self?.closeAbout() }))
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        p.contentViewController = hc
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        aboutPopover = p
        aboutMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeAbout()
        }
    }

    func closeAbout() {
        aboutPopover?.performClose(nil)
        aboutPopover = nil
        if let m = aboutMonitor { NSEvent.removeMonitor(m); aboutMonitor = nil }
    }

    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "RainbowApple")
                ?? {
                    // Fallback: draw a small coloured circle
                    let img = NSImage(size: NSSize(width: 18, height: 18))
                    img.lockFocus()
                    NSColor.systemGreen.setFill()
                    NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 12, height: 12)).fill()
                    img.unlockFocus()
                    return img
                }()
        }

        let menu = NSMenu()
        let aboutItem = NSMenuItem(title: "About RainbowApple", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit RainbowApple", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
