import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case scrolling
    case modifierKeys
    case app

    static let defaultTab: SettingsTab = .scrolling

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .scrolling:
            "Scrolling"
        case .modifierKeys:
            "Modifier Keys"
        case .app:
            "App"
        }
    }

    var symbolName: String {
        switch self {
        case .scrolling:
            "computermouse"
        case .modifierKeys:
            "command"
        case .app:
            "gearshape"
        }
    }

    var keyboardShortcutCharacter: Character {
        switch self {
        case .scrolling: "1"
        case .modifierKeys: "2"
        case .app: "3"
        }
    }

    var keyboardShortcutDescription: String {
        "Command-\(keyboardShortcutCharacter)"
    }

    func adjacent(_ direction: SettingsTabNavigationDirection) -> SettingsTab {
        let tabs = Self.allCases
        guard let index = tabs.firstIndex(of: self) else {
            return Self.defaultTab
        }
        switch direction {
        case .previous:
            return tabs[(index - 1 + tabs.count) % tabs.count]
        case .next:
            return tabs[(index + 1) % tabs.count]
        }
    }

    static func resolve(_ rawValue: String?) -> SettingsTab {
        guard let rawValue else { return defaultTab }
        if rawValue == "advancedScrolling" {
            return .scrolling
        }
        if rawValue == "systemHealth" {
            return .app
        }
        return SettingsTab(rawValue: rawValue) ?? defaultTab
    }
}

enum SettingsTabNavigationDirection {
    case previous
    case next
}
