import AppKit

enum JorvikWindowHelper {
    /// Centres a window on the display that currently has the mouse cursor.
    static func centreOnActiveDisplay(_ window: NSWindow) {
        // Find the screen containing the mouse
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        guard let screen = activeScreen else {
            window.center()
            return
        }

        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Shows a window on the space the user is on, and never switches spaces
    /// to reach it.
    ///
    /// A cached window can be closed, or still open on another space. Either
    /// way it is brought to this space, centred on the display with the
    /// pointer. Ordering front a window that is open on another space would
    /// otherwise switch the user to that space, which is what About used to do
    /// when it had been left open elsewhere. A window already on this space is
    /// just brought forward where it is.
    ///
    /// `.moveToActiveSpace` stays set. A window moves to the active space when
    /// it becomes active, and that happens only once `NSApp.activate` has
    /// finished, which is later than the call returns. Setting the flag for
    /// the moment of showing and removing it on the next run-loop turn, as
    /// this used to, removed it before it could act: a window closed or left
    /// open on another space went back there every time (measured on 27.0.1,
    /// 2026-10-11). It does not make the window follow the user around; a
    /// space switch does not activate it.
    static func showOnActiveSpace(_ window: NSWindow) {
        window.collectionBehavior.insert(.moveToActiveSpace)
        if !(window.isVisible && window.isOnActiveSpace) {
            centreOnActiveDisplay(window)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
