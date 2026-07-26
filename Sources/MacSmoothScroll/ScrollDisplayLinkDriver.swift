import AppKit
import CoreVideo
import QuartzCore

final class ScrollDisplayLinkDriver: NSObject {
    private let callback: (TimeInterval) -> Void
    private var lastTimestamp: TimeInterval?
    // Stored opaquely so the driver can retain macOS 13 deployment support
    // while using CADisplayLink on macOS 14 and newer.
    private var modernDisplayLink: AnyObject?
    private var legacyDisplayLink: CVDisplayLink?

    init(callback: @escaping (TimeInterval) -> Void) {
        self.callback = callback
    }

    var isRunning: Bool {
        modernDisplayLink != nil || legacyDisplayLink != nil
    }

    func start() {
        guard !isRunning else { return }
        lastTimestamp = nil

        if #available(macOS 14.0, *),
           let screen = screenUnderPointer ?? NSScreen.main ?? NSScreen.screens.first {
            let displayLink = screen.displayLink(
                target: self,
                selector: #selector(displayLinkDidFire(_:))
            )
            displayLink.add(to: .main, forMode: .common)
            modernDisplayLink = displayLink
            return
        }

        startLegacyDisplayLink()
    }

    func stop() {
        if #available(macOS 14.0, *),
           let displayLink = modernDisplayLink as? CADisplayLink {
            displayLink.invalidate()
        }
        modernDisplayLink = nil

        if let legacyDisplayLink {
            CVDisplayLinkStop(legacyDisplayLink)
        }
        legacyDisplayLink = nil
        lastTimestamp = nil
    }

    @available(macOS 14.0, *)
    @objc private func displayLinkDidFire(_ displayLink: CADisplayLink) {
        let timestamp = displayLink.targetTimestamp
        deliverFrame(
            timestamp: timestamp,
            fallbackDuration: displayLink.duration
        )
    }

    private func startLegacyDisplayLink() {
        var displayLink: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&displayLink) == kCVReturnSuccess,
              let displayLink else {
            return
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(
            displayLink,
            { _, _, outputTime, _, _, context in
                guard let context else { return kCVReturnError }
                let driver = Unmanaged<ScrollDisplayLinkDriver>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                let timestamp = Double(outputTime.pointee.hostTime) / CVGetHostClockFrequency()
                DispatchQueue.main.async {
                    driver.deliverFrame(timestamp: timestamp, fallbackDuration: 1.0 / 60.0)
                }
                return kCVReturnSuccess
            },
            context
        )

        guard CVDisplayLinkStart(displayLink) == kCVReturnSuccess else {
            return
        }
        legacyDisplayLink = displayLink
    }

    private var screenUnderPointer: NSScreen? {
        let pointerLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointerLocation) }
    }

    private func deliverFrame(
        timestamp: TimeInterval,
        fallbackDuration: TimeInterval
    ) {
        guard isRunning else { return }
        let elapsedTime: TimeInterval
        if let lastTimestamp {
            elapsedTime = timestamp - lastTimestamp
        } else {
            elapsedTime = fallbackDuration
        }
        lastTimestamp = timestamp

        guard elapsedTime > 0 else { return }
        callback(elapsedTime)
    }

    deinit {
        stop()
    }
}
