import SwiftUI

/// One external contribution acknowledged in the About window. The
/// contribution is a short summary of what they added, semicolon-joined
/// when there are several: "notification overlay; Simplified Chinese".
struct JorvikCredit: Hashable {
    let name: String
    let contribution: String
    let url: URL?

    init(name: String, contribution: String, url: URL? = nil) {
        self.name = name
        self.contribution = contribution
        self.url = url
    }
}

struct JorvikAboutView: View {
    let appName: String
    let repoName: String
    let productPage: String?
    let credits: [JorvikCredit]

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

            Text(L10n.format("about.version_format", defaultValue: "Version %@", version))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text(L10n.string(
                    "about.public_domain",
                    defaultValue: "Public Domain — No Rights Reserved"
                ))
                    .font(.caption)
                    .fontWeight(.medium)

                Text(L10n.string(
                    "about.license_details",
                    defaultValue: "Do whatever you like with this.\nSource code included. No attribution required.\nNo conditions. Yours."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !credits.isEmpty {
                Divider()
                    .padding(.horizontal, 40)

                VStack(spacing: 6) {
                    Text(L10n.string(
                        "about.contributors",
                        defaultValue: "With contributions from"
                    ))
                        .font(.caption)
                        .fontWeight(.medium)

                    ForEach(credits, id: \.self) { credit in
                        VStack(spacing: 1) {
                            if let url = credit.url {
                                Link(credit.name, destination: url)
                                    .font(.caption)
                            } else {
                                Text(credit.name)
                                    .font(.caption)
                            }
                            Text(credit.contribution)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                // Claim vertical space to wrap within the fixed
                                // window width — without this, fittingSize lets
                                // the line truncate instead of growing downward.
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                Link(
                    L10n.string("about.source_code", defaultValue: "Source Code"),
                    destination: URL(string: "https://github.com/PerpetualBeta/\(repoName)")!
                )
                    .font(.caption)

                if let page = productPage {
                    Link(
                        L10n.string("about.product_page", defaultValue: "Product Page"),
                        destination: URL(string: "https://jorviksoftware.cc/\(page)")!
                    )
                        .font(.caption)
                }
            }

            Button(L10n.string("about.close", defaultValue: "Close")) {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 300)
    }

    /// Cached window so repeat invocations focus the existing one instead
    /// of stacking duplicates. `isReleasedWhenClosed = false` keeps the
    /// object alive after the user closes it; we just re-show.
    private static var existingWindow: NSWindow?

    static func showWindow(
        appName: String,
        repoName: String,
        productPage: String? = nil,
        credits: [JorvikCredit] = []
    ) {
        if let window = existingWindow {
            // Whether it was closed or left open on another space, it comes to
            // this one; showing it never switches spaces.
            JorvikWindowHelper.showOnActiveSpace(window)
            return
        }

        let controller = NSHostingController(rootView: JorvikAboutView(
            appName: appName,
            repoName: repoName,
            productPage: productPage,
            credits: credits
        ))

        controller.view.layoutSubtreeIfNeeded()

        let window = NSWindow(contentViewController: controller)
        window.title = L10n.format("menu.about_format", defaultValue: "About %@", appName)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(controller.view.fittingSize)
        JorvikWindowHelper.showOnActiveSpace(window)
        existingWindow = window
    }
}
