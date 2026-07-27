import Foundation

enum SetupStep: Int, CaseIterable, Identifiable {
    case applications
    case accessibility
    case scrollTest
    case launchAtLogin

    var id: Int { rawValue }
}

enum FirstRunSetup {
    static func isInstalledInApplications(_ applicationURL: URL) -> Bool {
        let path = applicationURL.standardizedFileURL.path
        return path == "/Applications" || path.hasPrefix("/Applications/")
    }
}
