import CoreGraphics

enum ScrollGesturePhase: Equatable {
    case began
    case changed
    case ended
}

struct ScrollGestureEmission: Equatable {
    let phase: ScrollGesturePhase
    let flags: CGEventFlags
}

struct ScrollGestureLifecycle {
    private(set) var isActive = false
    private(set) var outputFlags: CGEventFlags = []

    mutating func prepareForBurst(flags: CGEventFlags) {
        outputFlags = flags
    }

    mutating func phaseForOutput(
        trackpadSimulation: Bool
    ) -> ScrollGestureEmission? {
        guard trackpadSimulation else { return nil }

        let phase: ScrollGesturePhase = isActive ? .changed : .began
        isActive = true
        return ScrollGestureEmission(phase: phase, flags: outputFlags)
    }

    mutating func finish() -> ScrollGestureEmission? {
        let emission = isActive
            ? ScrollGestureEmission(phase: .ended, flags: outputFlags)
            : nil
        reset()
        return emission
    }

    mutating func reset() {
        isActive = false
        outputFlags = []
    }
}
