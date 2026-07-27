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
    let minimumStepDistance: Double
    let feel: ScrollFeel
    let reverseDirection: Bool
    let adaptivePrecision: Bool
    let horizontalModifier: ModifierKey
    let zoomModifier: ModifierKey
    let swiftModifier: ModifierKey
    let preciseModifier: ModifierKey
}

struct ScrollImpulse: Equatable {
    let x: Double
    let y: Double
}

struct ScrollTransformResult: Equatable {
    let impulse: ScrollImpulse
    let outputFlags: CGEventFlags
    let beginsNewBurst: Bool
}

struct ScrollInputTransformer {
    private enum LockedAxis {
        case horizontal
        case vertical
    }

    private static let burstIdleInterval = 0.22
    private static let forwardedModifierFlags: CGEventFlags = [
        .maskShift,
        .maskControl,
        .maskAlternate,
        .maskCommand,
        .maskSecondaryFn
    ]
    private var lastPhysicalEventTime: TimeInterval?
    private var lockedAxis: LockedAxis?
    private var burstFlags: CGEventFlags = []
    private var rapidInputLevel = 0.0

    mutating func reset() {
        lastPhysicalEventTime = nil
        lockedAxis = nil
        burstFlags = []
        rapidInputLevel = 0
    }

    mutating func transform(
        _ sample: ScrollInputSample,
        using configuration: ScrollTransformConfiguration
    ) -> ScrollTransformResult {
        let interval = lastPhysicalEventTime.map { sample.timestamp - $0 }
        let beginsNewBurst = interval.map { $0 > Self.burstIdleInterval } ?? true

        if beginsNewBurst {
            lockedAxis = nil
            rapidInputLevel = 0
            burstFlags = sample.flags.intersection(Self.forwardedModifierFlags)
        }
        lastPhysicalEventTime = sample.timestamp

        var x = sample.pointX == 0 ? sample.lineX * 18 : sample.pointX
        var y = sample.pointY == 0 ? sample.lineY * 18 : sample.pointY

        let horizontalAction = configuration.horizontalModifier.isActive(in: burstFlags) &&
            abs(y) >= abs(x)
        let preciseAction = configuration.preciseModifier.isActive(in: burstFlags)
        let swiftAction = configuration.swiftModifier.isActive(in: burstFlags)

        if horizontalAction {
            x = y
            y = 0
            lockedAxis = .horizontal
        } else {
            applyDominantAxisLock(x: &x, y: &y)
        }

        var baseMultiplier = configuration.speed.multiplier
        if configuration.reverseDirection {
            baseMultiplier *= -1
        }
        if !preciseAction,
           !swiftAction,
           configuration.adaptivePrecision {
            baseMultiplier *= adaptivePrecisionMultiplier(interval: interval)
        }

        if !preciseAction {
            baseMultiplier *= rapidInputMultiplier(
                interval: interval,
                maximumBoost: configuration.feel.rapidInputBoost
            )
        }

        x *= baseMultiplier
        y *= baseMultiplier
        x = applyingMinimumStep(to: x, minimum: configuration.minimumStepDistance)
        y = applyingMinimumStep(to: y, minimum: configuration.minimumStepDistance)

        var modifierMultiplier = 1.0
        if preciseAction {
            modifierMultiplier = 0.28
        } else if swiftAction {
            modifierMultiplier = 2.4
        }

        let impulseScale = modifierMultiplier * (1 - configuration.smoothness.decay)
        var outputFlags: CGEventFlags = []
        let transformedActionActive = horizontalAction || preciseAction || swiftAction
        if !transformedActionActive,
           configuration.zoomModifier.isActive(in: burstFlags) {
            outputFlags.insert(configuration.zoomModifier.flag)
        }

        return ScrollTransformResult(
            impulse: ScrollImpulse(x: x * impulseScale, y: y * impulseScale),
            outputFlags: outputFlags,
            beginsNewBurst: beginsNewBurst
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
            }
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

    private func applyingMinimumStep(
        to value: Double,
        minimum: Double
    ) -> Double {
        guard value != 0 else { return 0 }
        return value.sign == .minus
            ? -max(abs(value), minimum)
            : max(abs(value), minimum)
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
        maximumBoost: Double
    ) -> Double {
        guard let interval else { return 1 }

        if interval < 0.055 {
            rapidInputLevel += 0.28
        } else if interval < 0.09 {
            rapidInputLevel += 0.16
        } else {
            rapidInputLevel -= 0.25
        }
        rapidInputLevel = min(max(rapidInputLevel, 0), 1)
        return 1 + (rapidInputLevel * maximumBoost)
    }
}

extension ScrollSettings {
    var scrollTransformConfiguration: ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            minimumStepDistance: minimumStepDistance,
            feel: feel,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            horizontalModifier: horizontalModifier,
            zoomModifier: zoomModifier,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
