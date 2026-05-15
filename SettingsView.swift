import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("outputDirectory") private var outputDirectory: String = ""
    @State private var launchAtLogin: Bool = false

    var outputURL: URL {
        if outputDirectory.isEmpty {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        return URL(fileURLWithPath: outputDirectory)
    }

    var shortOutputPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let full = outputURL.path
        let tilde = full.replacingOccurrences(of: home, with: "~")
        return tilde
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("settings_output_folder", comment: ""))
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 10) {
                Text(outputURL.path)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button(NSLocalizedString("settings_change", comment: "")) {
                        selectFolder()
                    }

                    Button(NSLocalizedString("settings_reset", comment: "")) {
                        outputDirectory = ""
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            HStack {
                Text(NSLocalizedString("settings_launch_at_login", comment: ""))
                    .fontWeight(.medium)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url.path
        }
    }

    func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enable
        }
    }
}

#Preview {
    SettingsView()
}
