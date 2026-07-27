import AppKit
import Foundation
import OSLog

@main
struct MacSmoothScrollLauncher {
    private static let logger = Logger(
        subsystem: "com.ronnel.mac-smooth-scroll.launcher",
        category: "LoginItem"
    )

    static func main() async {
        let helperURL = Bundle.main.bundleURL
        let mainAppURL = LoginItemLauncher.mainApplicationURL(from: helperURL)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--background"]

        do {
            try await LoginItemLauncher.launch {
                _ = try await NSWorkspace.shared.openApplication(
                    at: mainAppURL,
                    configuration: configuration
                )
            }
        } catch {
            logger.fault(
                "Could not launch the main app after retries: \(error.localizedDescription, privacy: .public)"
            )
            fputs("Mac Smooth Scroll Launcher: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}
