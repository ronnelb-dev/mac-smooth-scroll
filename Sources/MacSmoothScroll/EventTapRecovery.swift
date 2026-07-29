import Foundation

enum EventTapDisableReason: Equatable {
    case timeout
    case userInput
    case healthCheck
}

enum EventTapRecoveryAction: Equatable {
    case reenable
    case rebuild
}

struct EventTapRecoveryPolicy {
    private let repeatedDisableLimit: Int
    private let repeatedDisableWindow: TimeInterval
    private var disableTimes: [TimeInterval] = []

    init(
        repeatedDisableLimit: Int = 3,
        repeatedDisableWindow: TimeInterval = 10
    ) {
        self.repeatedDisableLimit = repeatedDisableLimit
        self.repeatedDisableWindow = repeatedDisableWindow
    }

    mutating func action(
        for reason: EventTapDisableReason,
        at timestamp: TimeInterval
    ) -> EventTapRecoveryAction {
        guard reason != .healthCheck else {
            return .rebuild
        }

        disableTimes.removeAll {
            timestamp - $0 > repeatedDisableWindow
        }
        disableTimes.append(timestamp)

        return disableTimes.count >= repeatedDisableLimit ? .rebuild : .reenable
    }

    mutating func reset() {
        disableTimes.removeAll()
    }
}
