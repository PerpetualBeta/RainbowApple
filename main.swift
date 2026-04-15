import Cocoa
import CoreText
import SwiftUI
import ServiceManagement
import ApplicationServices

// MARK: - Rainbow Apple Logo View

class RainbowAppleView: NSView {
    var fontSize: CGFloat = 22

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let appleChar = "\u{F8FF}"
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
    var positionSource: DispatchSourceTimer?
    var lastAXFrame: NSRect?
    let updateChecker = JorvikUpdateChecker(repoName: "RainbowApple")

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            DispatchQueue.main.async { self?.positionOverlay() }
        }
        source.resume()
        positionSource = source

        // Refresh pill on appearance change (light/dark mode)
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    @objc func appearanceChanged() {
        if let button = statusItem.button {
            JorvikMenuBarPill.refresh(on: button)
        }
    }

    func applyPill() {
        if let button = statusItem.button {
            JorvikMenuBarPill.apply(to: button)
        }
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
        window.contentView = RainbowAppleView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
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
            if let view = overlayWindow.contentView as? RainbowAppleView {
                view.fontSize = frame.height * 0.80
                view.needsDisplay = true
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

        if let view = overlayWindow.contentView as? RainbowAppleView {
            view.fontSize = 22 * scale
            view.needsDisplay = true
        }
    }

    @objc func repositionOverlay() {
        positionOverlay()
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
            MenuBarPillSettings {
                self?.applyPill()
            }
        }
    }

    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: "RainbowApple")
                ?? {
                    let img = NSImage(size: NSSize(width: 18, height: 18))
                    img.lockFocus()
                    NSColor.systemGreen.setFill()
                    NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 12, height: 12)).fill()
                    img.unlockFocus()
                    return img
                }()
        }

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
