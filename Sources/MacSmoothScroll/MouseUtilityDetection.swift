import Foundation

enum MouseUtilityDisposition: Equatable {
    case blocking
    case advisory
}

struct DetectedMouseUtility: Equatable {
    let name: String
    let disposition: MouseUtilityDisposition
}

struct MouseUtilityDetection: Equatable {
    let utilities: [DetectedMouseUtility]

    var blockingDriverRunning: Bool {
        utilities.contains { $0.disposition == .blocking }
    }

    var advisoryNames: [String] {
        utilities
            .filter { $0.disposition == .advisory }
            .map(\.name)
    }
}

struct MouseUtilityDetector {
    private struct Definition {
        let name: String
        let bundleIdentifierPrefixes: [String]
        let disposition: MouseUtilityDisposition
    }

    private static let definitions = [
        Definition(
            name: "Mac Mouse Fix",
            bundleIdentifierPrefixes: ["com.nuebling.mac-mouse-fix"],
            disposition: .blocking
        ),
        Definition(
            name: "LinearMouse",
            bundleIdentifierPrefixes: [
                "com.lujjjh.LinearMouse",
                "com.lujjjh.dev.LinearMouse"
            ],
            disposition: .advisory
        ),
        Definition(
            name: "Mos",
            bundleIdentifierPrefixes: ["com.caldis.Mos"],
            disposition: .advisory
        )
    ]

    func detect(bundleIdentifiers: [String]) -> MouseUtilityDetection {
        let identifiers = Set(bundleIdentifiers.filter { !$0.isEmpty })
        let utilities = Self.definitions.compactMap {
            definition -> DetectedMouseUtility? in
            guard identifiers.contains(where: { identifier in
                definition.bundleIdentifierPrefixes.contains { prefix in
                    identifier == prefix || identifier.hasPrefix(prefix + ".")
                }
            }) else {
                return nil
            }
            return DetectedMouseUtility(
                name: definition.name,
                disposition: definition.disposition
            )
        }
        return MouseUtilityDetection(utilities: utilities)
    }
}
