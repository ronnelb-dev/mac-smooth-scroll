import Foundation

struct ScrollMotionOutput: Equatable {
    let x: Int32
    let y: Int32
    let finished: Bool
}

struct ScrollMotionController {
    private static let referenceFrameRate = 120.0
    private static let stopVelocity = 0.025
    private static let maximumOutputPerFrame: Int32 = 120

    private(set) var velocityX = 0.0
    private(set) var velocityY = 0.0
    private var remainderX = 0.0
    private var remainderY = 0.0

    var isActive: Bool {
        velocityX != 0 || velocityY != 0 || remainderX != 0 || remainderY != 0
    }

    mutating func add(
        _ impulse: ScrollImpulse,
        feel: ScrollFeel,
        maximumVelocityMultiplier: Double = 1
    ) -> Bool {
        let reversedX = brakesForDirectionChange(current: velocityX, incoming: impulse.x)
        let reversedY = brakesForDirectionChange(current: velocityY, incoming: impulse.y)

        if reversedX {
            velocityX *= feel.directionChangeRetention
            discardRetainedVelocityIfItOverpowers(
                velocity: &velocityX,
                incoming: impulse.x
            )
            remainderX = 0
        }
        if reversedY {
            velocityY *= feel.directionChangeRetention
            discardRetainedVelocityIfItOverpowers(
                velocity: &velocityY,
                incoming: impulse.y
            )
            remainderY = 0
        }

        let velocityLimit = feel.maximumVelocity * maximumVelocityMultiplier
            .clamped(to: 1...3)
        velocityX = (velocityX + impulse.x).clamped(to: -velocityLimit...velocityLimit)
        velocityY = (velocityY + impulse.y).clamped(to: -velocityLimit...velocityLimit)
        return reversedX || reversedY
    }

    mutating func step(
        elapsedTime: TimeInterval,
        decay: Double
    ) -> ScrollMotionOutput {
        guard isActive else {
            return ScrollMotionOutput(x: 0, y: 0, finished: true)
        }

        // Integrate the complete elapsed interval so a delayed display-link
        // callback does not discard distance. Large accumulated output remains
        // in the fractional remainder and drains over bounded frames.
        let elapsedFrames = elapsedTime.isFinite
            ? elapsedTime * Self.referenceFrameRate
            : 0.25
        let referenceFrames = max(elapsedFrames, 0.25)
        let effectiveDecay = pow(decay, referenceFrames)
        let integrationScale = decay == 1
            ? referenceFrames
            : (1 - effectiveDecay) / (1 - decay)

        remainderX += velocityX * integrationScale
        remainderY += velocityY * integrationScale
        velocityX *= effectiveDecay
        velocityY *= effectiveDecay

        let outputX = boundedOutput(from: remainderX)
        let outputY = boundedOutput(from: remainderY)
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

    private func discardRetainedVelocityIfItOverpowers(
        velocity: inout Double,
        incoming: Double
    ) {
        if velocity.sign != incoming.sign,
           abs(velocity) >= abs(incoming) {
            velocity = 0
        }
    }

    private func boundedOutput(from value: Double) -> Int32 {
        let limit = Double(Self.maximumOutputPerFrame)
        return Int32(
            value
                .clamped(to: -limit...limit)
                .rounded(.towardZero)
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
