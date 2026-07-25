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
    let reverseDirection: Bool
    let adaptivePrecision: Bool
    let horizontalModifier: ModifierKey
    let swiftModifier: ModifierKey
    let preciseModifier: ModifierKey
}

struct ScrollImpulse: Equatable {
    let x: Double
    let y: Double
}

struct ScrollInputTransformer {
    private var lastPhysicalEventTime: TimeInterval?

    mutating func reset() {
        lastPhysicalEventTime = nil
    }

    mutating func transform(
        _ sample: ScrollInputSample,
        using configuration: ScrollTransformConfiguration
    ) -> ScrollImpulse {
        var x = sample.pointX == 0 ? sample.lineX * 18 : sample.pointX
        var y = sample.pointY == 0 ? sample.lineY * 18 : sample.pointY

        if configuration.horizontalModifier.isActive(in: sample.flags),
           abs(y) >= abs(x) {
            x = y
            y = 0
        }

        var multiplier = configuration.speed.multiplier
        if configuration.reverseDirection {
            multiplier *= -1
        }
        if configuration.swiftModifier.isActive(in: sample.flags) {
            multiplier *= 2.4
        }
        if configuration.preciseModifier.isActive(in: sample.flags) {
            multiplier *= 0.28
        } else if configuration.adaptivePrecision {
            if let lastPhysicalEventTime {
                let interval = sample.timestamp - lastPhysicalEventTime
                if interval > 0.18 {
                    multiplier *= 0.28
                } else if interval > 0.10 {
                    multiplier *= 0.52
                }
            }
            lastPhysicalEventTime = sample.timestamp
        }

        let impulseScale = multiplier * (1 - configuration.smoothness.decay)
        return ScrollImpulse(x: x * impulseScale, y: y * impulseScale)
    }
}

extension ScrollSettings {
    var scrollTransformConfiguration: ScrollTransformConfiguration {
        ScrollTransformConfiguration(
            smoothness: smoothness,
            speed: speed,
            reverseDirection: reverseDirection,
            adaptivePrecision: adaptivePrecision,
            horizontalModifier: horizontalModifier,
            swiftModifier: swiftModifier,
            preciseModifier: preciseModifier
        )
    }
}
