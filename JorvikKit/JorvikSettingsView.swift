import SwiftUI
import ServiceManagement

struct JorvikSettingsView<AppSettings: View>: View {
    let appName: String
    @Bindable var updateChecker: JorvikUpdateChecker
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

                Section("Updates") {
                    Picker("Check for updates", selection: $updateChecker.checkInterval) {
                        ForEach(UpdateCheckInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }

                    Toggle("Auto-install updates", isOn: $updateChecker.autoInstall)
                        .help("When enabled, updates are downloaded and installed automatically. The app will relaunch after installing.")

                    HStack {
                        updateStatusView

                        Spacer()

                        if case .available(_, _) = updateChecker.status {
                            if updateChecker.autoInstall {
                                Button("Install Now") {
                                    Task { await updateChecker.checkNow() }
                                }
                            } else {
                                Button("Download") {
                                    updateChecker.openReleasePage()
                                }
                            }
                        }

                        Button("Check Now") {
                            Task { await updateChecker.checkNow() }
                        }
                        .disabled(updateChecker.status == .checking)
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
            .padding(.bottom, 12)
        }
        .frame(width: 420, height: 500)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.status {
        case .unknown:
            Text("Not checked yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Checking...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .upToDate(let version):
            Label("Up to date (v\(version))", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .available(let version, _):
            Label("Update available: v\(version)", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text(progress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    static func showWindow(appName: String, updateChecker: JorvikUpdateChecker, @ViewBuilder appSettings: @escaping () -> AppSettings) {
        let view = JorvikSettingsView(
            appName: appName,
            updateChecker: updateChecker,
            appSettings: appSettings
        )
        let controller = NSHostingController(rootView: view)
        // Let the hosting controller compute its preferred size
        controller.view.layoutSubtreeIfNeeded()
        let fittingSize = controller.view.fittingSize
        let size = NSSize(width: max(fittingSize.width, 420), height: max(fittingSize.height, 400))

        let window = NSWindow(contentViewController: controller)
        window.title = "\(appName) Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        JorvikWindowHelper.centreOnActiveDisplay(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
