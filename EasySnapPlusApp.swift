import SwiftUI

@main
struct EasySnapPlusApp: App {
    @AppStorage("colorScheme") private var colorSchemePreference: String = "system"
    @Environment(\.openWindow) private var openWindow

    var selectedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedColorScheme)
                .frame(minWidth: 360, maxWidth: 360, minHeight: 760, maxHeight: 760)
                .onDisappear {
                    NSApplication.shared.terminate(nil)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About EasySnap+") {
                    openWindow(id: "about")
                }
            }
            CommandMenu("Appearance") {
                Button("System Default") {
                    colorSchemePreference = "system"
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
                Button("Light Mode") {
                    colorSchemePreference = "light"
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("Dark Mode") {
                    colorSchemePreference = "dark"
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            }
        }

        Window("About EasySnap+", id: "about") {
            AboutView()
                .fixedSize()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
