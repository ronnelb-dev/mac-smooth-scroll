import CoreGraphics
import Foundation

enum ZoomBehavior: String, CaseIterable, Identifiable {
    case pinch
    case page

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinch: "Pinch-style"
        case .page: "Page zoom"
        }
    }
}

enum PageZoomDirection: Equatable {
    case zoomIn
    case zoomOut
}

enum ScrollTransformOutput: Equatable {
    case scroll(flags: CGEventFlags)
    case pinchZoom
    case pageZoom(direction: PageZoomDirection?)
}

enum MagnificationPhase: Int64, Equatable {
    case began = 1
    case changed = 2
    case ended = 4
}

struct MagnificationEventDescriptor: Equatable {
    let magnification: Double
    let phase: MagnificationPhase
}

struct MagnificationLifecycle {
    private static let scale = 800.0
    private static let chromiumZoomInBoost = 380.0 / scale
    private static let chromiumZoomOutBoost = 250.0 / scale

    private(set) var isActive = false
    private var usesChromiumBoost = false

    mutating func prepareForBurst(isChromium: Bool) {
        usesChromiumBoost = isChromium
    }

    mutating func events(
        x: Int32,
        y: Int32
    ) -> [MagnificationEventDescriptor] {
        let magnification = Double(x + y) / Self.scale
        guard magnification != 0 else { return [] }

        if isActive {
            return [
                MagnificationEventDescriptor(
                    magnification: magnification,
                    phase: .changed
                )
            ]
        }

        isActive = true
        let began = MagnificationEventDescriptor(
            magnification: magnification,
            phase: .began
        )
        guard usesChromiumBoost else { return [began] }

        let boost = magnification > 0
            ? Self.chromiumZoomInBoost
            : -Self.chromiumZoomOutBoost
        return [
            began,
            MagnificationEventDescriptor(
                magnification: magnification + boost,
                phase: .changed
            )
        ]
    }

    mutating func finish() -> MagnificationEventDescriptor? {
        guard isActive else {
            reset()
            return nil
        }
        reset()
        return MagnificationEventDescriptor(
            magnification: 0,
            phase: .ended
        )
    }

    mutating func reset() {
        isActive = false
        usesChromiumBoost = false
    }
}

struct ChromiumBundleClassifier {
    private static let prefixes = [
        "com.google.Chrome",
        "org.chromium.Chromium",
        "company.thebrowser.Browser",
        "com.operasoftware.Opera",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.brave.Browser"
    ]

    func matches(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return Self.prefixes.contains { bundleIdentifier.hasPrefix($0) }
    }
}

struct PageZoomCommandDescriptor: Equatable {
    let direction: PageZoomDirection
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}

struct PageZoomController {
    static let minimumInterval = 0.1
    static let zoomInKeyCode: CGKeyCode = 24
    static let zoomOutKeyCode: CGKeyCode = 27

    private var lastCommandTime: TimeInterval?

    mutating func command(
        for direction: PageZoomDirection?,
        at timestamp: TimeInterval
    ) -> PageZoomCommandDescriptor? {
        guard let direction, timestamp.isFinite else { return nil }
        if let lastCommandTime,
           timestamp >= lastCommandTime,
           timestamp - lastCommandTime < Self.minimumInterval {
            return nil
        }

        self.lastCommandTime = timestamp
        switch direction {
        case .zoomIn:
            return PageZoomCommandDescriptor(
                direction: direction,
                keyCode: Self.zoomInKeyCode,
                flags: [.maskCommand, .maskShift]
            )
        case .zoomOut:
            return PageZoomCommandDescriptor(
                direction: direction,
                keyCode: Self.zoomOutKeyCode,
                flags: .maskCommand
            )
        }
    }

    mutating func reset() {
        lastCommandTime = nil
    }
}
