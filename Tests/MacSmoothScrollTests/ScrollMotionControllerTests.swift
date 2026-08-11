import XCTest
@testable import MacSmoothScroll

final class ScrollMotionControllerTests: XCTestCase {
    func testIntegrationPreservesDistanceAcrossRefreshRates() {
        let distanceAt60Hz = integratedDistance(frameRate: 60)
        let distanceAt120Hz = integratedDistance(frameRate: 120)
        let distanceAt144Hz = integratedDistance(frameRate: 144)

        XCTAssertEqual(distanceAt60Hz, distanceAt120Hz, accuracy: 1)
        XCTAssertEqual(distanceAt144Hz, distanceAt120Hz, accuracy: 1)
    }

    func testElevatedVelocityPreservesDistanceAcrossRefreshRates() {
        let distanceAt60Hz = integratedDistance(
            frameRate: 60,
            impulse: 90,
            maximumVelocityMultiplier: 3
        )
        let distanceAt120Hz = integratedDistance(
            frameRate: 120,
            impulse: 90,
            maximumVelocityMultiplier: 3
        )
        let distanceAt144Hz = integratedDistance(
            frameRate: 144,
            impulse: 90,
            maximumVelocityMultiplier: 3
        )

        XCTAssertEqual(distanceAt60Hz, distanceAt120Hz, accuracy: 1)
        XCTAssertEqual(distanceAt144Hz, distanceAt120Hz, accuracy: 1)
    }

    func testLongFrameDelayBoundsRetainedDistanceAndCatchUpTail() {
        let normalDistance = integratedDistance(
            frameRate: 120,
            impulse: 30
        )
        var delayedMotion = ScrollMotionController()
        _ = delayedMotion.add(
            ScrollImpulse(x: 0, y: 30),
            feel: .glide
        )

        let delayedFrame = delayedMotion.step(
            elapsedTime: 0.5,
            decay: Smoothness.high.decay
        )
        var delayedDistance = Double(delayedFrame.y)
        var emittedCatchUpFrames = 0

        for _ in 0..<1_000 {
            let output = delayedMotion.step(
                elapsedTime: 1.0 / 120.0,
                decay: Smoothness.high.decay
            )
            delayedDistance += Double(output.y)
            if output.x != 0 || output.y != 0 {
                emittedCatchUpFrames += 1
            }
            if output.finished { break }
        }

        XCTAssertEqual(delayedFrame.y, 120)
        XCTAssertLessThan(delayedDistance, normalDistance / 2)
        XCTAssertLessThanOrEqual(emittedCatchUpFrames, 8)
        XCTAssertFalse(delayedMotion.isActive)
    }

    func testRetainedIntervalBoundaryPreservesNormalIntegratedDistance() {
        let normalDistance = integratedDistance(
            frameRate: 120,
            impulse: 30
        )
        let boundaryDistance = integratedDistance(
            initialDelay: ScrollMotionController.maximumRetainedElapsedTime,
            impulse: 30
        )

        XCTAssertEqual(boundaryDistance, normalDistance, accuracy: 1)
    }

    func testIncreasingAbnormalDelayDoesNotIncreaseRetainedDebt() {
        let shortStallDistance = integratedDistance(
            initialDelay: 0.25,
            impulse: 30
        )
        let longStallDistance = integratedDistance(
            initialDelay: 1.0,
            impulse: 30
        )

        XCTAssertLessThanOrEqual(longStallDistance, shortStallDistance)
        XCTAssertLessThan(shortStallDistance, 200)
    }

    func testElevatedVelocityStillHasBoundedStallDebt() {
        let shorterStallDistance = elevatedVelocityDistance(initialDelay: 0.25)
        let longerStallDistance = elevatedVelocityDistance(initialDelay: 1.0)

        XCTAssertLessThanOrEqual(longerStallDistance, shorterStallDistance)
        XCTAssertLessThan(shorterStallDistance, 600)
    }

    func testVelocityIsCappedByFeelPreset() {
        var motion = ScrollMotionController()

        for _ in 0..<20 {
            _ = motion.add(
                ScrollImpulse(x: 0, y: 10),
                feel: .balanced
            )
        }

        XCTAssertEqual(motion.velocityY, ScrollFeel.balanced.maximumVelocity)
    }

    func testDynamicVelocityMultiplierRaisesFeelPresetCeiling() {
        var motion = ScrollMotionController()

        for _ in 0..<30 {
            _ = motion.add(
                ScrollImpulse(x: 0, y: 20),
                feel: .glide,
                maximumVelocityMultiplier: 3
            )
        }

        XCTAssertEqual(
            motion.velocityY,
            ScrollFeel.glide.maximumVelocity * 3,
            accuracy: 0.0001
        )
    }

    func testDirectionChangeBrakesExistingMomentum() {
        var motion = ScrollMotionController()
        _ = motion.add(ScrollImpulse(x: 0, y: 10), feel: .balanced)

        let reversed = motion.add(
            ScrollImpulse(x: 0, y: -2),
            feel: .balanced
        )

        XCTAssertTrue(reversed)
        XCTAssertLessThan(motion.velocityY, 0)
        XCTAssertEqual(motion.velocityY, -1.2, accuracy: 0.0001)
    }

    func testDirectionChangeDiscardsElevatedOppositeMomentum() {
        var motion = ScrollMotionController()
        for _ in 0..<30 {
            _ = motion.add(
                ScrollImpulse(x: 0, y: 20),
                feel: .glide,
                maximumVelocityMultiplier: 3
            )
        }

        let reversed = motion.add(
            ScrollImpulse(x: 0, y: -2),
            feel: .glide,
            maximumVelocityMultiplier: 3
        )

        XCTAssertTrue(reversed)
        XCTAssertEqual(motion.velocityY, -2, accuracy: 0.0001)
    }

    func testDynamicVelocityStillHonorsPerFrameSafetyCap() {
        var motion = ScrollMotionController()
        for _ in 0..<30 {
            _ = motion.add(
                ScrollImpulse(x: 0, y: 20),
                feel: .glide,
                maximumVelocityMultiplier: 3
            )
        }

        let output = motion.step(
            elapsedTime: 0.5,
            decay: Smoothness.high.decay
        )

        XCTAssertEqual(output.y, 120)
    }

    func testControllerStopsAndClearsItsState() {
        var motion = ScrollMotionController()
        _ = motion.add(ScrollImpulse(x: 0, y: 1), feel: .balanced)

        var finished = false
        for _ in 0..<500 where !finished {
            finished = motion.step(
                elapsedTime: 1.0 / 120.0,
                decay: Smoothness.low.decay
            ).finished
        }

        XCTAssertTrue(finished)
        XCTAssertFalse(motion.isActive)
        XCTAssertEqual(motion.velocityY, 0)
    }

    func testResetClearsVelocityAndFractionalRemainder() {
        var motion = ScrollMotionController()
        _ = motion.add(
            ScrollImpulse(x: 0.2, y: 0.2),
            feel: .balanced
        )
        _ = motion.step(
            elapsedTime: 1.0 / 120.0,
            decay: Smoothness.high.decay
        )
        XCTAssertTrue(motion.isActive)

        motion.reset()

        XCTAssertFalse(motion.isActive)
        XCTAssertEqual(motion.velocityX, 0)
        XCTAssertEqual(motion.velocityY, 0)
    }

    private func integratedDistance(
        frameRate: Double,
        impulse: Double = 4,
        maximumVelocityMultiplier: Double = 1
    ) -> Double {
        var motion = ScrollMotionController()
        _ = motion.add(
            ScrollImpulse(x: 0, y: impulse),
            feel: .glide,
            maximumVelocityMultiplier: maximumVelocityMultiplier
        )
        var distance = 0.0

        for _ in 0..<1_000 {
            let output = motion.step(
                elapsedTime: 1 / frameRate,
                decay: Smoothness.high.decay
            )
            distance += Double(output.y)
            if output.finished { break }
        }
        return distance
    }

    private func integratedDistance(
        initialDelay: TimeInterval,
        impulse: Double
    ) -> Double {
        var motion = ScrollMotionController()
        _ = motion.add(
            ScrollImpulse(x: 0, y: impulse),
            feel: .glide
        )
        var distance = Double(
            motion.step(
                elapsedTime: initialDelay,
                decay: Smoothness.high.decay
            ).y
        )

        for _ in 0..<1_000 {
            let output = motion.step(
                elapsedTime: 1.0 / 120.0,
                decay: Smoothness.high.decay
            )
            distance += Double(output.y)
            if output.finished { break }
        }
        return distance
    }

    private func elevatedVelocityDistance(
        initialDelay: TimeInterval
    ) -> Double {
        var motion = ScrollMotionController()
        for _ in 0..<30 {
            _ = motion.add(
                ScrollImpulse(x: 0, y: 20),
                feel: .glide,
                maximumVelocityMultiplier: 3
            )
        }
        var distance = Double(
            motion.step(
                elapsedTime: initialDelay,
                decay: Smoothness.high.decay
            ).y
        )

        for _ in 0..<1_000 {
            let output = motion.step(
                elapsedTime: 1.0 / 120.0,
                decay: Smoothness.high.decay
            )
            distance += Double(output.y)
            if output.finished { break }
        }
        return distance
    }
}
