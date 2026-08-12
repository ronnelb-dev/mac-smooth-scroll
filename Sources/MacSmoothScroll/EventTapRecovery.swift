import Foundation

enum EventTapDisableReason: Equatable {
    case timeout
    case userInput
    case healthCheck
}

enum EventTapRecoveryAction: Equatable {
    case reenable
    case rebuild
    case stop
}

struct EventTapRecoveryPolicy {
    private let repeatedDisableLimit: Int
    private let repeatedDisableWindow: TimeInterval
    private let maximumRebuildAttempts: Int
    private let rebuildAttemptWindow: TimeInterval
    private var disableTimes: [TimeInterval] = []
    private var rebuildTimes: [TimeInterval] = []

    init(
        repeatedDisableLimit: Int = 3,
        repeatedDisableWindow: TimeInterval = 10,
        maximumRebuildAttempts: Int = 3,
        rebuildAttemptWindow: TimeInterval = 30
    ) {
        self.repeatedDisableLimit = max(1, repeatedDisableLimit)
        self.repeatedDisableWindow = max(0, repeatedDisableWindow)
        self.maximumRebuildAttempts = max(1, maximumRebuildAttempts)
        self.rebuildAttemptWindow = max(0, rebuildAttemptWindow)
    }

    mutating func action(
        for reason: EventTapDisableReason,
        at timestamp: TimeInterval
    ) -> EventTapRecoveryAction {
        guard timestamp.isFinite else { return .stop }
        guard reason != .healthCheck else {
            return rebuildAction(at: timestamp)
        }

        prune(&disableTimes, at: timestamp, window: repeatedDisableWindow)
        disableTimes.append(timestamp)

        return disableTimes.count >= repeatedDisableLimit
            ? rebuildAction(at: timestamp)
            : .reenable
    }

    mutating func didCompleteRebuild() {
        disableTimes.removeAll()
    }

    mutating func reset() {
        disableTimes.removeAll()
        rebuildTimes.removeAll()
    }

    private mutating func rebuildAction(
        at timestamp: TimeInterval
    ) -> EventTapRecoveryAction {
        prune(&rebuildTimes, at: timestamp, window: rebuildAttemptWindow)
        guard rebuildTimes.count < maximumRebuildAttempts else {
            return .stop
        }
        rebuildTimes.append(timestamp)
        return .rebuild
    }

    private func prune(
        _ timestamps: inout [TimeInterval],
        at timestamp: TimeInterval,
        window: TimeInterval
    ) {
        timestamps.removeAll {
            timestamp >= $0 && timestamp - $0 > window
        }
    }
}
