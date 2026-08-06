import CoreGraphics
import Foundation

struct ScrollInputSample {
    let lineX: Double
    let lineY: Double
    let pointX: Double
    let pointY: Double
    let flags: CGEventFlags
    let timestamp: TimeInterval
}

struct ScrollTransformConfiguration {
    let smoothness: Smoothness
    let speed: ScrollSpeed
    let minimumStepEnabled: Bool
    let minimumStepDistance: Double
    let feel: ScrollFeel
    let reverseDirection: Bool
    let adaptivePrecision: Bool
    let accelerationEnabled: Bool
    let axisLockEnabled: Bool
    let horizontalModifier: ModifierKey
    let zoomModifier: ModifierKey
    let zoomBehavior: ZoomBehavior
    let swiftModifier: ModifierKey
    let preciseModifier: ModifierKey
}

struct ScrollImpulse: Equatable {
    let x: Double
    let y: Double
}

struct ScrollTransformResult: Equatable {
    let impulse: ScrollImpulse
    let output: ScrollTransformOutput
    let beginsNewBurst: Bool
    let velocityLimitMultiplier: Double
}

struct ScrollInputTransformer {
    private enum LockedAxis {
        case horizontal
        case vertical
    }

    private enum TravelDirection: Equatable {
        case horizontalNegative
        case horizontalPositive
        case verticalNegative
        case verticalPositive
    }

    private static let burstIdleInterval = 0.22
    private static let longDistanceMaximumInterval = 0.16
    private static let longDistanceRampStart = 0.4
    private static let longDistanceRampEnd = 1.0
    private static let longDistanceMaximumMultiplier = 3.0
    private static let forwardedModifierFlags: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskCommand,
        .maskSecondaryFn
    ]
    private var lastPhysicalEventTime: TimeInterval?
    private var lockedAxis: LockedAxis?
    private var pendingAxisSwitch: LockedAxis?
    private var pendingAxisSwitchCount = 0
    private var burstFlags: CGEventFlags = []
    private var rapidInputLevel = 0.0
    private var sustainedRapidDuration = 0.0
    private var lastAccelerationDirection: TravelDirection?
    private let modifierResolver = ScrollModifierResolver()

    mutating func reset() {
        lastPhysicalEventTime = nil
        lockedAxis = nil
        resetPendingAxisSwitch()
        burstFlags = []
        resetAccelerationState()
    }

    mutating func transform(
        _ sample: ScrollInputSample,
        using configuration: ScrollTransformConfiguration
    ) -> ScrollTransformResult {
        let interval = lastPhysicalEventTime.map { sample.timestamp - $0 }
        let beginsNewBurst = interval.map { $0 > Self.burstIdleInterval } ?? true

        if beginsNewBurst {
            lockedAxis = nil
            resetPendingAxisSwitch()
            resetAccelerationState()
            burstFlags = sample.flags.intersection(Self.forwardedModifierFlags)
        }
        lastPhysicalEventTime = sample.timestamp

        var x = sample.pointX == 0 ? sample.lineX * 18 : sample.pointX
        var y = sample.pointY == 0 ? sample.lineY * 18 : sample.pointY

        let modifierResolution = modifierResolver.resolve(
            x: x,
            y: y,
            flags: burstFlags,
            configuration: configuration
        )

        if modifierResolution.zoomActive,
           configuration.zoomBehavior == .page {
            resetAccelerationState()
            let dominantDelta = abs(y) >= abs(x) ? y : x
            let directedDelta = configuration.reverseDirection
                ? -dominantDelta
                : dominantDelta
            let direction: PageZoomDirection?
            if directedDelta > 0 {
                direction = .zoomIn
            } else if directedDelta < 0 {
                direction = .zoomOut
            } else {
                direction = nil
            }
            return ScrollTransformResult(
                impulse: ScrollImpulse(x: 0, y: 0),
                output: .pageZoom(direction: direction),
                beginsNewBurst: beginsNewBurst,
                velocityLimitMultiplier: 1
            )
        }

        if modifierResolution.convertsToHorizontal {
            x = y
            y = 0
        }
        let accelerationDirection = dominantTravelDirection(x: x, y: y)

        if modifierResolution.convertsToHorizontal {
            lockedAxis = .horizontal
            resetPendingAxisSwitch()
        } else if configuration.axisLockEnabled {
            applyDominantAxisLock(x: &x, y: &y)
        } else {
            lockedAxis = nil
            resetPendingAxisSwitch()
        }

        var baseMultiplier = configuration.speed.multiplier
        if configuration.reverseDirection {
            baseMultiplier *= -1
        }
        if modifierResolution.speedAction.allowsAdaptivePrecision,
           configuration.adaptivePrecision {
            baseMultiplier *= adaptivePrecisionMultiplier(interval: interval)
        }

        let longDistanceMultiplier: Double
        if modifierResolution.speedAction.allowsRapidInputAcceleration,
           configuration.accelerationEnabled {
            let acceleration = accelerationMultipliers(
                interval: interval,
                inputDistance: max(abs(x), abs(y)),
                direction: accelerationDirection,
                maximumRapidInputBoost: configuration.feel.rapidInputBoost
            )
            baseMultiplier *= acceleration.rapidInput
            longDistanceMultiplier = acceleration.longDistance
        } else {
            resetAccelerationState()
            longDistanceMultiplier = 1
        }

        x *= baseMultiplier
        y *= baseMultiplier
        if configuration.minimumStepEnabled {
            applyMinimumStep(
                x: &x,
                y: &y,
                minimum: configuration.minimumStepDistance
            )
        }

        let impulseScale =
            modifierResolution.speedAction.multiplier *
            longDistanceMultiplier *
            (1 - configuration.smoothness.decay)

        return ScrollTransformResult(
            impulse: ScrollImpulse(x: x * impulseScale, y: y * impulseScale),
            output: modifierResolution.zoomActive
                ? .pinchZoom
                : .scroll(flags: []),
            beginsNewBurst: beginsNewBurst,
            velocityLimitMultiplier: longDistanceMultiplier
        )
    }

    private mutating func applyDominantAxisLock(
        x: inout Double,
        y: inout Double
    ) {
        if lockedAxis == nil {
            let larger = max(abs(x), abs(y))
            let smaller = min(abs(x), abs(y))
            if larger >= 2, smaller == 0 || larger / smaller >= 1.2 {
                lockedAxis = abs(x) > abs(y) ? .horizontal : .vertical
                resetPendingAxisSwitch()
            }
        } else if updateAxisLockForDirectionChange(x: x, y: y) {
            x = 0
            y = 0
            return
        }

        switch lockedAxis {
        case .horizontal:
            y = 0
        case .vertical:
            x = 0
        case nil:
            break
        }
    }

    private mutating func updateAxisLockForDirectionChange(
        x: Double,
        y: Double
    ) -> Bool {
        let candidate: LockedAxis?
        switch lockedAxis {
        case .horizontal:
            candidate = isStronglyDominant(primary: y, secondary: x)
                ? .vertical
                : nil
        case .vertical:
            candidate = isStronglyDominant(primary: x, secondary: y)
                ? .horizontal
                : nil
        case nil:
            candidate = nil
        }

        guard let candidate else {
            resetPendingAxisSwitch()
            return false
        }

        if pendingAxisSwitch == candidate {
            pendingAxisSwitchCount += 1
        } else {
            pendingAxisSwitch = candidate
            pendingAxisSwitchCount = 1
        }

        if pendingAxisSwitchCount >= 2 {
            lockedAxis = candidate
            resetPendingAxisSwitch()
            return false
        }
        return true
    }

    private func isStronglyDominant(
        primary: Double,
        secondary: Double
    ) -> Bool {
        let primaryMagnitude = abs(primary)
        let secondaryMagnitude = abs(secondary)
        guard primaryMagnitude >= 2 else { return false }
        return secondaryMagnitude == 0 ||
            primaryMagnitude / secondaryMagnitude >= 1.8
    }

    private mutating func resetPendingAxisSwitch() {
        pendingAxisSwitch = nil
        pendingAxisSwitchCount = 0
    }

    private func applyMinimumStep(
        x: inout Double,
        y: inout Double,
        minimum: Double
    ) {
        let magnitude = hypot(x, y)
        guard magnitude > 0, magnitude < minimum else { return }

        let scale = minimum / magnitude
        x *= scale
        y *= scale
    }

    private func adaptivePrecisionMultiplier(
        interval: TimeInterval?
    ) -> Double {
        guard let interval else { return 0.30 }
        if interval >= 0.18 { return 0.30 }
        if interval <= 0.06 { return 1 }

        let progress = (0.18 - interval) / 0.12
        return 0.30 + (0.70 * progress)
    }

    private mutating func rapidInputMultiplier(
        interval: TimeInterval?,
        inputDistance: Double,
        maximumBoost: Double
    ) -> Double {
        guard let interval else {
            rapidInputLevel = 0
            return 1
        }
        guard interval >= 0, interval < 0.12 else {
            rapidInputLevel = 0
            return 1
        }

        // Build acceleration from total physical movement and elapsed time
        // instead of event count. Mice that split the same wheel movement into
        // more events therefore reach the same acceleration level.
        rapidInputLevel -= interval
        rapidInputLevel += inputDistance / 72
        rapidInputLevel = min(max(rapidInputLevel, 0), 1)
        return 1 + (rapidInputLevel * maximumBoost)
    }

    private mutating func accelerationMultipliers(
        interval: TimeInterval?,
        inputDistance: Double,
        direction: TravelDirection?,
        maximumRapidInputBoost: Double
    ) -> (rapidInput: Double, longDistance: Double) {
        guard inputDistance > 0, let direction else {
            resetAccelerationState()
            return (1, 1)
        }

        guard let interval,
              interval >= 0,
              interval <= Self.longDistanceMaximumInterval else {
            resetAccelerationState()
            lastAccelerationDirection = direction
            return (1, 1)
        }

        if lastAccelerationDirection == direction {
            sustainedRapidDuration += interval
        } else {
            rapidInputLevel = 0
            sustainedRapidDuration = 0
            lastAccelerationDirection = direction
        }

        let rapidInput = rapidInputMultiplier(
            interval: interval,
            inputDistance: inputDistance,
            maximumBoost: maximumRapidInputBoost
        )
        let rampRange =
            Self.longDistanceRampEnd - Self.longDistanceRampStart
        let linearProgress = (
            (sustainedRapidDuration - Self.longDistanceRampStart) / rampRange
        ).clamped(to: 0...1)
        let smoothProgress =
            linearProgress * linearProgress * (3 - (2 * linearProgress))
        let longDistance = 1 + (
            (Self.longDistanceMaximumMultiplier - 1) * smoothProgress
        )
        return (rapidInput, longDistance)
    }

    private func dominantTravelDirection(
        x: Double,
        y: Double
    ) -> TravelDirection? {
        if abs(x) > abs(y) {
            guard x != 0 else { return nil }
            return x < 0 ? .horizontalNegative : .horizontalPositive
        }
        guard y != 0 else { return nil }
        return y < 0 ? .verticalNegative : .verticalPositive
    }

    private mutating func resetAccelerationState() {
        rapidInputLevel = 0
        sustainedRapidDuration = 0
        lastAccelerationDirection = nil
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension ScrollSettings {
    var scrollTransformConfiguration: ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            minimumStepEnabled: minimumStepEnabled,
            minimumStepDistance: minimumStepDistance,
            feel: feel,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            accelerationEnabled: accelerationEnabled,
            axisLockEnabled: axisLockEnabled,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            zoomBehavior: zoomBehavior,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
