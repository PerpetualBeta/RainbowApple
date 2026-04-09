import SwiftUI

struct JorvikAboutView: View {
    let appName: String
    let repoName: String
    let productPage: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text(appName)
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(version)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Public Domain — No Rights Reserved")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("Do whatever you like with this.\nSource code included. No attribution required.\nNo conditions. Yours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Link("Source Code", destination: URL(string: "https://github.com/PerpetualBeta/\(repoName)")!)
                    .font(.caption)

                if let page = productPage {
                    Link("Product Page", destination: URL(string: "https://jorviksoftware.cc/\(page)")!)
                        .font(.caption)
                }
            }

            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 300)
    }

    static func showWindow(appName: String, repoName: String, productPage: String? = nil) {
        let controller = NSHostingController(rootView: JorvikAboutView(
            appName: appName,
            repoName: repoName,
            productPage: productPage
        ))

        controller.view.layoutSubtreeIfNeeded()

        let window = NSWindow(contentViewController: controller)
        window.title = "About \(appName)"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(controller.view.fittingSize)
        JorvikWindowHelper.centreOnActiveDisplay(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
