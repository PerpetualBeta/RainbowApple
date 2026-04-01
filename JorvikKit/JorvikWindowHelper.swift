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
}
