import SwiftUI
import ServiceManagement

struct JorvikSettingsView<AppSettings: View>: View {
    let appName: String
    /// Whether to offer **Launch at Login**.
    ///
    /// Defaults to `true`, which is right for the menu-bar apps this shell was
    /// written for: an agent that is not running does nothing, so starting it at
    /// login is the point. It is wrong for an app you open, use and quit — offering
    /// to launch a wallpaper editor at every login invites the user to leave
    /// something resident that has no reason to be.
    ///
    /// A defaulted parameter rather than an edit, so every app that already copies
    /// this file keeps its current behaviour untouched.
    var showsLaunchAtLogin: Bool = true
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

                if showsLaunchAtLogin {
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
                }

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
            // Matching the bottom inset. Without a top inset the button row sits
            // flush against the form, and a form long enough to scroll ends its
            // visible area on a half-clipped row right against the button.
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        // A floor, not a fixed size — `showWindow` sizes the window from this
        // view's `fittingSize`, so a fixed size there made the measurement a
        // constant and every settings window came out the same small pane with a
        // scroller however much room the display had.
        .frame(minWidth: JorvikSettingsMetrics.minContentSize.width,
               minHeight: JorvikSettingsMetrics.minContentSize.height)
    }

    static func showWindow(
        appName: String,
        showsLaunchAtLogin: Bool = true,
        @ViewBuilder appSettings: @escaping () -> AppSettings
    ) {
        if let window = JorvikSettingsWindowCache.existingWindow {
            // Sized for whichever display it last appeared on, which may not be this one.
            JorvikSettingsWindowCache.sizer?.clamp()
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
            showsLaunchAtLogin: showsLaunchAtLogin,
            appSettings: appSettings
        )
        let controller = NSHostingController(rootView: view)
        // Let the hosting controller compute its preferred size
        controller.view.layoutSubtreeIfNeeded()
        let fittingSize = controller.view.fittingSize

        // Shrink or grow to the content on both axes, floored at the minimum
        // above and capped at a fraction of the display the window will open on.
        // A form larger than the cap keeps its scroller, so the window never runs
        // off the screen; a form smaller than the floor still gets a window worth
        // looking at.
        //
        // Measured against the screen under the pointer, which is where
        // `centreOnActiveDisplay` is about to put it. The height budget pays for
        // the title bar too: `setContentSize` takes a *content* height and the
        // chrome is added on top, so the title bar comes out of the budget or it
        // is spent twice. (A titled window adds no width, hence height only.)
        let style: NSWindow.StyleMask = [.titled, .closable]
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let size = JorvikSettingsMetrics.contentSize(fitting: fittingSize, on: screen, style: style)

        let window = NSWindow(contentViewController: controller)
        window.title = "\(appName) Settings"
        window.styleMask = style
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        // The cause, rather than the symptom: left to itself AppKit hands
        // first-responder status to the first text field in the form. The scroll
        // correction below stays as the safety net, since SwiftUI's own focus
        // machinery can still claim it after this point.
        window.initialFirstResponder = nil
        JorvikWindowHelper.centreOnActiveDisplay(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scrollToTop(controller.view, in: window)
        JorvikSettingsWindowCache.existingWindow = window
        // The cap has to survive the display changing under it. A window sized for a
        // 27-inch panel is taller than a laptop screen, and a user who switches to the
        // built-in display then cannot reach the bottom of the form — the window is off
        // the screen and there is nothing to drag it back by.
        JorvikSettingsWindowCache.sizer = JorvikSettingsWindowSizer(window: window)
    }
}

/// Non-generic cache for the settings window instance. `JorvikSettingsView`
/// is generic over the app-specific settings type, and Swift doesn't allow
/// static stored properties inside generic types — so the cache sits here.
private enum JorvikSettingsWindowCache {
    static var existingWindow: NSWindow?
    /// Keeps the window inside whatever display it finds itself on. Held here because it
    /// has to outlive `showWindow`, exactly as the window itself does.
    static var sizer: JorvikSettingsWindowSizer?
}

/// Holds a settings window to the display cap after the display has changed.
///
/// The cap is applied when the window is built, against the screen it is about to appear
/// on — and then the world moves: the user switches from an external panel to the built-in
/// one, unplugs a display, or drags the window somewhere smaller. A window that was 80% of
/// a 1440-tall screen is *taller than* a 1080-tall one, and once its bottom edge is off the
/// screen the form cannot be scrolled to the end and the window cannot be dragged up,
/// because macOS pins the title bar below the menu bar.
///
/// So the same arithmetic is re-applied on the two events that can invalidate it, and when
/// a cached window is shown again.
final class JorvikSettingsWindowSizer: NSObject {

    private weak var window: NSWindow?

    init(window: NSWindow) {
        self.window = window
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSWindow.didChangeScreenNotification, object: window)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func displaysChanged() {
        // A beat late on purpose: at the moment the notification arrives the window may not
        // yet have been moved onto the surviving display, so measuring now would measure
        // the screen it is leaving.
        DispatchQueue.main.async { [weak self] in self?.clamp() }
    }

    /// Bring the window back inside the current display's cap, and back on screen.
    func clamp() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let fitting = window.contentViewController?.view.fittingSize ?? window.frame.size
        let capped = JorvikSettingsMetrics.contentSize(fitting: fitting, on: screen,
                                                      style: window.styleMask)
        if window.contentView?.frame.size != capped { window.setContentSize(capped) }
        // Sizing alone is not enough: a window whose top-left stayed put can still hang off
        // the bottom. Nudge it back inside the visible area.
        var frame = window.frame
        let visible = screen.visibleFrame
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        if frame != window.frame { window.setFrame(frame, display: true) }
    }
}

private extension JorvikSettingsView {

    /// Open at the top of the form.
    ///
    /// AppKit hands first-responder status to the first text field when the
    /// window is shown, then scrolls the form to reveal it — so a settings form
    /// with a text field part-way down opens *scrolled to that field*, past the
    /// sections above it. Harmless on a form that fits; very visible on one long
    /// enough to scroll, which is now any form taller than 80% of the display.
    ///
    /// Applied across a short settle window rather than once, because the scroll
    /// being undone here doesn't happen at one predictable moment: focus is
    /// assigned partly when the window is shown and partly when it becomes key,
    /// and `NSApp.activate` makes the second of those asynchronous. Doing it on a
    /// single run-loop turn left the form scrolled about one launch in three.
    ///
    /// Safe to repeat: the whole window is well under the time it takes anyone to
    /// reach the scroll wheel, so this can't fight a scroll the user meant.
    static func scrollToTop(_ root: NSView, in window: NSWindow) {
        for delay in JorvikSettingsMetrics.scrollSettleDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { apply(root, in: window) }
        }
    }

    private static func apply(_ root: NSView, in window: NSWindow) {
        do {
            // Nothing focused, so nothing to scroll back to. A field still takes
            // focus on click; it just doesn't claim it uninvited.
            window.makeFirstResponder(nil)
            guard let scroller = firstScrollView(in: root),
                  let document = scroller.documentView else { return }
            // A flipped document has its origin at the top; an unflipped one has
            // the top at its full height less what's on screen.
            let top = document.isFlipped
                ? NSPoint.zero
                : NSPoint(x: 0, y: max(0, document.bounds.height - scroller.contentSize.height))
            scroller.contentView.scroll(to: top)
            scroller.reflectScrolledClipView(scroller.contentView)
        }
    }

    static func firstScrollView(in view: NSView) -> NSScrollView? {
        if let scroller = view as? NSScrollView { return scroller }
        for subview in view.subviews {
            if let found = firstScrollView(in: subview) { return found }
        }
        return nil
    }
}

/// Sizing metrics for the settings window. A separate enum for the same reason
/// the cache is one: a generic type can't hold static stored properties.
private enum JorvikSettingsMetrics {
    /// The smallest a settings window gets, however little it contains. The view
    /// and the window sizing both read this so they can't drift apart.
    static let minContentSize = NSSize(width: 420, height: 400)

    /// The most of a display's visible area a settings window may take.
    ///
    /// A fraction rather than a fixed inset: a settings window that fills the
    /// screen reads as a document window, and one fixed inset can't suit both a
    /// laptop panel and a 27-inch display.
    static let maxDisplayFraction: CGFloat = 0.80

    /// Fallback when there is no screen to measure — vanishingly unlikely, and a
    /// plausible small display beats a zero-size window.
    static let assumedScreenSize = NSSize(width: 1200, height: 900)

    /// The content size a settings window should have on a given screen: the form's own
    /// fitting size, floored so a tiny form still gets a window worth looking at, and
    /// capped at `maxDisplayFraction` of the display.
    ///
    /// The height budget pays for the title bar too — `setContentSize` takes a *content*
    /// height and the chrome is added on top, so the title bar comes out of the budget or
    /// it is spent twice. (A titled window adds no width, hence height only.)
    static func contentSize(fitting: NSSize, on screen: NSScreen?,
                           style: NSWindow.StyleMask) -> NSSize {
        let chromeHeight = NSWindow.frameRect(forContentRect: .zero, styleMask: style).height
        let visible = screen?.visibleFrame.size ?? assumedScreenSize
        // `max(..., floor)` on each ceiling so a display too small for the floor yields the
        // floor rather than an inverted range.
        let ceilingWidth = max(visible.width * maxDisplayFraction, minContentSize.width)
        let ceilingHeight = max(visible.height * maxDisplayFraction - chromeHeight,
                                minContentSize.height)
        return NSSize(width: min(max(fitting.width, minContentSize.width), ceilingWidth),
                      height: min(max(fitting.height, minContentSize.height), ceilingHeight))
    }

    /// When to re-assert the form's scroll position after the window is shown.
    /// See `JorvikSettingsView.scrollToTop` for why this is a window and not a
    /// single moment.
    static let scrollSettleDelays: [Double] = [0, 0.05, 0.25]
}
