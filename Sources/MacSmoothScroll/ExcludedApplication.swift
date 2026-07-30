import Foundation

struct ExcludedApplication: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    let name: String

    var id: String {
        bundleIdentifier
    }

    static func resolve(at url: URL) throws -> ExcludedApplication {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty
        else {
            throw ExcludedApplicationError.invalidApplication
        }

        let displayName =
            bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName =
            bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = [displayName, bundleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            ?? url.deletingPathExtension().lastPathComponent

        return ExcludedApplication(
            bundleIdentifier: bundleIdentifier,
            name: name
        )
    }
}

enum ExcludedApplicationError: LocalizedError {
    case invalidApplication

    var errorDescription: String? {
        switch self {
        case .invalidApplication:
            "Choose a macOS application with a valid bundle identifier."
        }
    }
}
