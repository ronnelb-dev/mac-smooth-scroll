import Foundation
import XCTest
@testable import MacSmoothScroll

final class WheelCalibrationTests: XCTestCase {
    func testCapturePolicyRejectsSyntheticOutput() {
        let policy = WheelCalibrationCapturePolicy()

        XCTAssertTrue(policy.shouldCapture(sourceUserData: 0))
        XCTAssertFalse(
            policy.shouldCapture(
                sourceUserData: ScrollEventFilter.syntheticMarker
            )
        )
    }

    func testTooFewDiscreteSamplesNeedMoreInput() {
        let result = WheelCalibrationAnalyzer().analyze(
            samples(count: 7, pointDistances: [18], interval: 0.06)
        )

        XCTAssertEqual(result.kind, .insufficient)
        XCTAssertNil(result.recommendation)
    }

    func testContinuousInputIsRecognizedAsNativePassThrough() {
        let result = WheelCalibrationAnalyzer().analyze(
            samples(
                count: 12,
                pointDistances: [2, 3, 4],
                interval: 0.01,
                isContinuous: true
            )
        )

        XCTAssertEqual(result.kind, .nativeContinuous)
        XCTAssertNil(result.recommendation)
    }

    func testRegularNotchesRecommendTheCurrentMinimumStepDefault() {
        let result = WheelCalibrationAnalyzer().analyze(
            samples(count: 16, pointDistances: [18], interval: 0.06)
        )

        XCTAssertEqual(result.kind, .notched)
        XCTAssertEqual(
            result.recommendation,
            WheelCalibrationRecommendation(
                minimumStepEnabled: true,
                minimumStepDistance: 18,
                minimumStepMultiplier: .standard
            )
        )
    }

    func testSmallRapidInputRecommendsDisablingMinimumStep() {
        let result = WheelCalibrationAnalyzer().analyze(
            samples(
                count: 16,
                pointDistances: [2, 3, 4, 5, 6, 7, 8, 9],
                interval: 0.015
            )
        )

        XCTAssertEqual(result.kind, .highResolution)
        XCTAssertEqual(result.recommendation?.minimumStepEnabled, false)
    }

    func testVariableSlowerInputUsesConservativeMixedRecommendation() {
        let result = WheelCalibrationAnalyzer().analyze(
            samples(
                count: 16,
                pointDistances: [8, 14, 20, 28, 36, 44, 52, 60],
                interval: 0.07
            )
        )

        XCTAssertEqual(result.kind, .mixed)
        XCTAssertEqual(result.recommendation?.minimumStepEnabled, true)
    }

    func testHorizontalInputIsReportedWithoutChangingClassification() {
        var captured = samples(count: 12, pointDistances: [18], interval: 0.06)
        for index in 0..<3 {
            let sample = captured[index]
            captured[index] = WheelCalibrationSample(
                lineX: sample.lineY,
                lineY: 0,
                pointX: sample.pointY,
                pointY: 0,
                isContinuous: false,
                timestamp: sample.timestamp
            )
        }

        let result = WheelCalibrationAnalyzer().analyze(captured)

        XCTAssertEqual(result.kind, .notched)
        XCTAssertTrue(result.horizontalInputObserved)
    }

    func testSessionStopsAtTargetCountAndReturnsAResult() {
        var session = WheelCalibrationSession()
        var result: WheelCalibrationResult?
        for sample in samples(
            count: WheelCalibrationAnalyzer.targetSampleCount,
            pointDistances: [18],
            interval: 0.06
        ) {
            result = session.record(sample) ?? result
        }

        XCTAssertEqual(session.sampleCount, WheelCalibrationAnalyzer.targetSampleCount)
        XCTAssertEqual(result?.kind, .notched)
    }

    func testSettingsApplyOnlyTheExplicitRecommendationAndDiscardSamples() {
        let suiteName = "WheelCalibrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = ScrollSettings(defaults: defaults, managesLaunchAtLogin: false)
        settings.minimumStepEnabled = true
        settings.minimumStepDistance = 42
        settings.minimumStepMultiplier = .triple
        settings.startWheelCalibration()

        for sample in samples(
            count: WheelCalibrationAnalyzer.targetSampleCount,
            pointDistances: [2, 3, 4, 5],
            interval: 0.01
        ) {
            settings.recordWheelCalibrationSample(sample)
        }

        XCTAssertFalse(settings.wheelCalibrationState.isCollecting)
        XCTAssertTrue(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, 42)
        XCTAssertEqual(settings.minimumStepMultiplier, .triple)

        settings.applyWheelCalibrationRecommendation()

        XCTAssertFalse(settings.minimumStepEnabled)
        XCTAssertEqual(settings.minimumStepDistance, 42)
        XCTAssertEqual(settings.minimumStepMultiplier, .triple)
        XCTAssertEqual(settings.wheelCalibrationState, .idle)
        XCTAssertNil(defaults.object(forKey: "scroll.calibrationSamples"))
    }

    func testSettingsIgnoreSamplesOutsideAnActiveCalibration() {
        let suiteName = "WheelCalibrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = ScrollSettings(defaults: defaults, managesLaunchAtLogin: false)

        settings.recordWheelCalibrationSample(
            samples(count: 1, pointDistances: [18], interval: 0.06)[0]
        )

        XCTAssertEqual(settings.wheelCalibrationState, .idle)
    }

    private func samples(
        count: Int,
        pointDistances: [Double],
        interval: TimeInterval,
        isContinuous: Bool = false
    ) -> [WheelCalibrationSample] {
        (0..<count).map { index in
            WheelCalibrationSample(
                lineX: 0,
                lineY: pointDistances[index % pointDistances.count] < 0 ? -1 : 1,
                pointX: 0,
                pointY: pointDistances[index % pointDistances.count],
                isContinuous: isContinuous,
                timestamp: Double(index) * interval
            )
        }
    }
}
