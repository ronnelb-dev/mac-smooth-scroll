import Foundation

struct WheelCalibrationSample: Equatable {
    let lineX: Double
    let lineY: Double
    let pointX: Double
    let pointY: Double
    let isContinuous: Bool
    let timestamp: TimeInterval

    var dominantPointDistance: Double {
        max(abs(pointX), abs(pointY))
    }

    var dominantLineDistance: Double {
        max(abs(lineX), abs(lineY))
    }

    var isHorizontalDominant: Bool {
        let pointDistance = dominantPointDistance
        if pointDistance > 0 {
            return abs(pointX) > abs(pointY)
        }
        return abs(lineX) > abs(lineY)
    }
}

enum WheelCalibrationKind: String, Equatable {
    case notched = "Notched wheel"
    case highResolution = "High-resolution or free-spinning wheel"
    case mixed = "Mixed wheel input"
    case nativeContinuous = "Native continuous input"
    case insufficient = "More input needed"
}

struct WheelCalibrationRecommendation: Equatable {
    let minimumStepEnabled: Bool
    let minimumStepDistance: Double?
    let minimumStepMultiplier: MinimumStepMultiplier?

    var summary: String {
        if minimumStepEnabled {
            return "Enable Minimum wheel step at 18.00 pt and 1×."
        }
        return "Turn off Minimum wheel step to avoid amplifying small rapid events."
    }
}

struct WheelCalibrationResult: Equatable {
    let kind: WheelCalibrationKind
    let sampleCount: Int
    let horizontalInputObserved: Bool
    let recommendation: WheelCalibrationRecommendation?

    var detail: String {
        switch kind {
        case .notched:
            "The captured events were regular and evenly spaced, which is typical of a notched wheel."
        case .highResolution:
            "The captured events were small and rapid, which is common with free-spinning or high-resolution wheels."
        case .mixed:
            "The captured events varied enough that a conservative standard setup is recommended."
        case .nativeContinuous:
            "This input already uses native continuous scrolling and is passed through unchanged. Try again with an external mouse wheel."
        case .insufficient:
            "Scroll a little farther with one external mouse, then finish the calibration again."
        }
    }
}

enum WheelCalibrationState: Equatable {
    case idle
    case collecting(sampleCount: Int)
    case result(WheelCalibrationResult)

    var isCollecting: Bool {
        if case .collecting = self { return true }
        return false
    }
}

struct WheelCalibrationCapturePolicy {
    func shouldCapture(sourceUserData: Int64) -> Bool {
        sourceUserData != ScrollEventFilter.syntheticMarker
    }
}

struct WheelCalibrationAnalyzer {
    static let minimumDiscreteSamples = 8
    static let targetSampleCount = 24

    func analyze(_ samples: [WheelCalibrationSample]) -> WheelCalibrationResult {
        let physicalSamples = samples.filter {
            $0.dominantPointDistance > 0 || $0.dominantLineDistance > 0
        }
        let continuousCount = physicalSamples.filter(\.isContinuous).count
        let discrete = physicalSamples.filter { !$0.isContinuous }

        if continuousCount >= max(4, (physicalSamples.count * 3) / 4) {
            return WheelCalibrationResult(
                kind: .nativeContinuous,
                sampleCount: physicalSamples.count,
                horizontalInputObserved: horizontalObserved(in: physicalSamples),
                recommendation: nil
            )
        }

        guard discrete.count >= Self.minimumDiscreteSamples else {
            return WheelCalibrationResult(
                kind: .insufficient,
                sampleCount: discrete.count,
                horizontalInputObserved: horizontalObserved(in: discrete),
                recommendation: nil
            )
        }

        let magnitudes = discrete.map { sample in
            let pointDistance = sample.dominantPointDistance
            return pointDistance > 0 ? pointDistance : sample.dominantLineDistance * 10
        }
        let intervals = zip(discrete, discrete.dropFirst()).compactMap { previous, current in
            let interval = current.timestamp - previous.timestamp
            return interval > 0 && interval <= 0.25 ? interval : nil
        }
        let medianInterval = median(intervals) ?? 0.25
        let smallShare = share(magnitudes) { $0 < ScrollStep.defaultValue }
        let roundedMagnitudes = magnitudes.map { Int($0.rounded()) }
        let mostCommonShare = Dictionary(grouping: roundedMagnitudes, by: { $0 })
            .values
            .map(\.count)
            .max()
            .map { Double($0) / Double(roundedMagnitudes.count) }
            ?? 0
        let uniqueShare = Double(Set(roundedMagnitudes).count) / Double(roundedMagnitudes.count)

        let kind: WheelCalibrationKind
        if (smallShare >= 0.65 && medianInterval <= 0.04) ||
            (uniqueShare >= 0.5 && medianInterval <= 0.03) {
            kind = .highResolution
        } else if mostCommonShare >= 0.6 {
            kind = .notched
        } else {
            kind = .mixed
        }

        let recommendation = WheelCalibrationRecommendation(
            minimumStepEnabled: kind != .highResolution,
            minimumStepDistance: kind == .highResolution
                ? nil
                : ScrollStep.defaultValue,
            minimumStepMultiplier: kind == .highResolution ? nil : .standard
        )
        return WheelCalibrationResult(
            kind: kind,
            sampleCount: discrete.count,
            horizontalInputObserved: horizontalObserved(in: discrete),
            recommendation: recommendation
        )
    }

    private func horizontalObserved(in samples: [WheelCalibrationSample]) -> Bool {
        guard !samples.isEmpty else { return false }
        let horizontalCount = samples.filter(\.isHorizontalDominant).count
        return Double(horizontalCount) / Double(samples.count) >= 0.2
    }

    private func share(
        _ values: [Double],
        matching predicate: (Double) -> Bool
    ) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.filter(predicate).count) / Double(values.count)
    }

    private func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

struct WheelCalibrationSession {
    private(set) var samples: [WheelCalibrationSample] = []
    private let analyzer = WheelCalibrationAnalyzer()

    var sampleCount: Int { samples.count }

    mutating func record(_ sample: WheelCalibrationSample) -> WheelCalibrationResult? {
        guard samples.count < WheelCalibrationAnalyzer.targetSampleCount else {
            return analyzer.analyze(samples)
        }
        samples.append(sample)
        guard samples.count == WheelCalibrationAnalyzer.targetSampleCount else {
            return nil
        }
        return analyzer.analyze(samples)
    }

    func finish() -> WheelCalibrationResult {
        analyzer.analyze(samples)
    }
}
