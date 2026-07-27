import Foundation

enum MenuBarRecoveryAction: Equatable {
    case none
    case openAccessibilitySettings
    case quitMacMouseFix
    case retryEngine

    var title: String? {
        switch self {
        case .none:
            nil
        case .openAccessibilitySettings:
            "Open Accessibility Settings…"
        case .quitMacMouseFix:
            "Quit Mac Mouse Fix"
        case .retryEngine:
            "Retry Scroll Engine"
        }
    }
}

struct MenuBarPresentation: Equatable {
    let statusTitle: String
    let statusSymbolName: String
    let statusItemSymbolName: String
    let statusItemAccessibilityLabel: String
    let smoothScrollingIsOn: Bool
    let recoveryAction: MenuBarRecoveryAction

    static func make(
        isEnabled: Bool,
        engineStatus: ScrollEngineStatus
    ) -> MenuBarPresentation {
        let symbol: String
        let statusItemSymbol: String
        let recovery: MenuBarRecoveryAction

        switch engineStatus {
        case .waiting:
            symbol = "clock.fill"
            statusItemSymbol = "computermouse"
            recovery = .retryEngine
        case .active:
            symbol = "checkmark.circle.fill"
            statusItemSymbol = "computermouse.fill"
            recovery = .none
        case .disabled:
            symbol = "pause.circle.fill"
            statusItemSymbol = "computermouse"
            recovery = .none
        case .permissionBlocked:
            symbol = "hand.raised.fill"
            statusItemSymbol = "exclamationmark.triangle.fill"
            recovery = .openAccessibilitySettings
        case .driverConflict:
            symbol = "exclamationmark.triangle.fill"
            statusItemSymbol = "exclamationmark.triangle.fill"
            recovery = .quitMacMouseFix
        case .startFailed:
            symbol = "xmark.circle.fill"
            statusItemSymbol = "exclamationmark.triangle.fill"
            recovery = .retryEngine
        }

        let statusTitle = engineStatus.message
        return MenuBarPresentation(
            statusTitle: statusTitle,
            statusSymbolName: symbol,
            statusItemSymbolName: statusItemSymbol,
            statusItemAccessibilityLabel: "Mac Smooth Scroll — \(statusTitle)",
            smoothScrollingIsOn: isEnabled,
            recoveryAction: recovery
        )
    }
}
