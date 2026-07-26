import Foundation

struct ScrollMotionOutput: Equatable {
    let x: Int32
    let y: Int32
    let finished: Bool
}

struct ScrollMotionController {
    private static let referenceFrameRate = 120.0
    private static let stopVelocity = 0.025

    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private var remainderX = 0.0
    private var remainderY = 0.0

    var isActive: Bool {
        velocityX != 0 || velocityY != 0 || remainderX != 0 || remainderY != 0
    }

    mutating func add(
        _ impulse: ScrollImpulse,
        feel: ScrollFeel
    ) -> Bool {
        let reversedX = brakesForDirectionChange(current: velocityX, incoming: impulse.x)
        let reversedY = brakesForDirectionChange(current: velocityY, incoming: impulse.y)

        if reversedX {
            velocityX *= feel.directionChangeRetention
            remainderX = 0
        }
        if reversedY {
            velocityY *= feel.directionChangeRetention
            remainderY = 0
        }

        velocityX = (velocityX + impulse.x).clamped(to: -feel.maximumVelocity...feel.maximumVelocity)
        velocityY = (velocityY + impulse.y).clamped(to: -feel.maximumVelocity...feel.maximumVelocity)
        return reversedX || reversedY
    }

    mutating func step(
        elapsedTime: TimeInterval,
        decay: Double
    ) -> ScrollMotionOutput {
        guard isActive else {
            return ScrollMotionOutput(x: 0, y: 0, finished: true)
        }

        // Integrate an exponential curve over the actual elapsed time. This
        // preserves the old 120 Hz total-distance behavior at every refresh rate.
        let referenceFrames = (elapsedTime * Self.referenceFrameRate).clamped(to: 0.25...4)
        let effectiveDecay = pow(decay, referenceFrames)
        let integrationScale = decay == 1
            ? referenceFrames
            : (1 - effectiveDecay) / (1 - decay)

        remainderX += velocityX * integrationScale
        remainderY += velocityY * integrationScale
        velocityX *= effectiveDecay
        velocityY *= effectiveDecay

        let outputX = Int32(remainderX.rounded(.towardZero))
        let outputY = Int32(remainderY.rounded(.towardZero))
        remainderX -= Double(outputX)
        remainderY -= Double(outputY)

        let finished =
            abs(velocityX) < Self.stopVelocity &&
            abs(velocityY) < Self.stopVelocity &&
            abs(remainderX) < 0.5 &&
            abs(remainderY) < 0.5

        if finished {
            reset()
        }

        return ScrollMotionOutput(x: outputX, y: outputY, finished: finished)
    }

    mutating func reset() {
        velocityX = 0
        velocityY = 0
        remainderX = 0
        remainderY = 0
    }

    private func brakesForDirectionChange(
        current: Double,
        incoming: Double
    ) -> Bool {
        abs(current) > Self.stopVelocity &&
            abs(incoming) > Self.stopVelocity &&
            current.sign != incoming.sign
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
