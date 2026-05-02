import SwiftUI
import ApplicationServices

/// App-specific settings sections shown inside JorvikSettingsView:
///  - Permissions (Accessibility status + grant button)
///  - Menu Bar Icon (JorvikKit's standard pill settings)
///
/// Launch at Login and Updates sections are provided by JorvikSettingsView
/// itself, so they don't need to appear here.
struct RainbowAppleSettingsContent: View {
    var onPillChanged: () -> Void

    var body: some View {
        Section("Permissions") {
            HStack {
                Text("Accessibility")
                Spacer()
                if AXIsProcessTrusted() {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Button("Grant Access") {
                        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                        AXIsProcessTrustedWithOptions(opts)
                    }
                    .font(.caption)
                }
            }
        }

        MenuBarPillSettings(onChanged: onPillChanged)
    }
}
