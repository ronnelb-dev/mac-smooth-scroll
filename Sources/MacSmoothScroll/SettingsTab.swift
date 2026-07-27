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
