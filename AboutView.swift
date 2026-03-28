import SwiftUI

struct AboutView: View {
    let appName: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }
            Text(appName)
                .font(.headline)
            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            Divider()
            VStack(spacing: 6) {
                Text("Public Domain — No Rights Reserved")
                    .font(.subheadline.weight(.medium))
                Text("Do whatever you like with this.\nSource code included. No attribution required. No conditions. Yours.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Divider()
            Button("Close") { onDismiss?() }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.vertical, 10)
        }
        .frame(width: 260)
        .background(Color(.windowBackgroundColor))
    }
}
