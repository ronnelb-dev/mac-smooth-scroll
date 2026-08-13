import Foundation

struct ApplicationScrollConfiguration: Codable, Equatable {
    var smoothness: Smoothness
    var speed: ScrollSpeed
    var minimumStepEnabled: Bool
    var minimumStepDistance: Double
    var minimumStepMultiplier: MinimumStepMultiplier
    var feel: ScrollFeel
    var trackpadSimulation: Bool
    var reverseDirection: Bool
    var adaptivePrecision: Bool
    var accelerationEnabled: Bool
    var longDistanceBoostEnabled: Bool
    var axisLockEnabled: Bool

    var sanitized: ApplicationScrollConfiguration {
        var copy = self
        copy.minimumStepDistance = ScrollStep.sanitized(minimumStepDistance)
        return copy
    }

    func transformConfiguration(
        horizontalModifier: ModifierKey,
        zoomModifier: ModifierKey,
        zoomBehavior: ZoomBehavior,
        swiftModifier: ModifierKey,
        preciseModifier: ModifierKey
    ) -> ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            minimumStepEnabled: minimumStepEnabled,
            minimumStepDistance: ScrollStep.sanitized(minimumStepDistance),
            minimumStepMultiplier: minimumStepMultiplier,
            feel: feel,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            accelerationEnabled: accelerationEnabled,
            longDistanceBoostEnabled: longDistanceBoostEnabled,
            axisLockEnabled: axisLockEnabled,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            zoomBehavior: zoomBehavior,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}

struct ApplicationScrollProfile: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    var name: String
    var isEnabled: Bool
    var configuration: ApplicationScrollConfiguration

    var id: String { bundleIdentifier }

    var sanitized: ApplicationScrollProfile {
        var copy = self
        copy.configuration = configuration.sanitized
        return copy
    }
}

struct ResolvedScrollRuntimeConfiguration: Equatable {
    let profileBundleIdentifier: String?
    let transform: ScrollTransformConfiguration
    let smoothness: Smoothness
    let feel: ScrollFeel
    let trackpadSimulation: Bool
}

struct ApplicationProfileContextTracker {
    private var isInitialized = false
    private var profileBundleIdentifier: String?

    mutating func shouldReset(
        for newProfileBundleIdentifier: String?
    ) -> Bool {
        let changed = isInitialized &&
            profileBundleIdentifier != newProfileBundleIdentifier
        isInitialized = true
        profileBundleIdentifier = newProfileBundleIdentifier
        return changed
    }

    mutating func reset() {
        isInitialized = false
        profileBundleIdentifier = nil
    }
}
