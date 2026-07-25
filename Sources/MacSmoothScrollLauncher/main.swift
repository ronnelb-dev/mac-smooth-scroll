import AppKit
import Foundation

@main
struct MacSmoothScrollLauncher {
    static func main() async {
        let helperURL = Bundle.main.bundleURL
        let mainAppURL = helperURL
            .deletingLastPathComponent() // LoginItems
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // Mac Smooth Scroll.app

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--background"]

        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: mainAppURL,
                configuration: configuration
            )
        } catch {
            fputs("Mac Smooth Scroll Launcher: \(error.localizedDescription)\n", stderr)
        }
    }
}
