import AppKit
import SwiftUI

/// An inline keyboard shortcut recorder for use in settings forms.
/// Displays the current shortcut, and when "Change..." is clicked,
/// switches to recording mode and captures the next key combo directly.
struct JorvikShortcutRecorder: View {
    let label: String
    @Binding var keyCode: UInt16
    @Binding var modifiers: NSEvent.ModifierFlags
    var displayString: () -> String
    var onChanged: (() -> Void)?
    var eventTapToDisable: CFMachPort?

    @State private var shortcutText: String = ""
    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if isRecording {
                Text("Press shortcut\u{2026}")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Button("Cancel") {
                    stopRecording()
                }
                .font(.caption)
            } else {
                Text(shortcutText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button("Change\u{2026}") {
                    startRecording()
                }
                .font(.caption)
            }
        }
        .onAppear {
            shortcutText = displayString()
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        // Disable event tap if provided (e.g. WindowPin's CGEvent tap)
        if let tap = eventTapToDisable {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        isRecording = true

        let handleEvent = { (event: NSEvent) in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Escape cancels
            if event.keyCode == 53 {
                stopRecording()
                shortcutText = displayString()
                return
            }

            // Require at least one modifier
            guard flags.contains(.command) || flags.contains(.control) || flags.contains(.option) else {
                return
            }

            let cleanFlags = flags.intersection([.command, .control, .option, .shift])
            keyCode = event.keyCode
            modifiers = cleanFlags
            onChanged?()
            stopRecording()
            shortcutText = displayString()
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleEvent(event)
            return nil
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleEvent(event)
        }
    }

    private func stopRecording() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        isRecording = false

        // Re-enable event tap
        if let tap = eventTapToDisable {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

extension Notification.Name {
    static let jorvikShortcutChanged = Notification.Name("JorvikShortcutChanged")
}

enum JorvikShortcutPanel {
    // MARK: - Utility: format a keyCode + modifiers as a display string

    static func displayString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToCharacter(keyCode))
        return parts.joined()
    }

    private static func keyCodeToCharacter(_ keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            50: "`", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 118: "F4", 120: "F2", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return map[keyCode] ?? "?\(keyCode)"
    }
}
