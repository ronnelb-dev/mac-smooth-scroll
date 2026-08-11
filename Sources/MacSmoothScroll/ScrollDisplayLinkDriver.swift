import AppKit
import CoreVideo
import QuartzCore

struct DisplayFrameSample: Equatable {
    let timestamp: TimeInterval
    let fallbackDuration: TimeInterval
}

struct DisplayFrameCoalescer {
    private(set) var generation: UInt64 = 0
    private(set) var pendingFrame: DisplayFrameSample?
    private(set) var deliveryScheduled = false
    private(set) var isActive = false

    mutating func beginSession() {
        generation &+= 1
        pendingFrame = nil
        deliveryScheduled = false
        isActive = true
    }

    mutating func endSession() {
        generation &+= 1
        pendingFrame = nil
        deliveryScheduled = false
        isActive = false
    }

    mutating func enqueue(_ frame: DisplayFrameSample) -> UInt64? {
        guard isActive else { return nil }
        pendingFrame = frame
        guard !deliveryScheduled else { return nil }
        deliveryScheduled = true
        return generation
    }

    mutating func takePending(for generation: UInt64) -> DisplayFrameSample? {
        guard isActive, self.generation == generation else { return nil }
        let frame = pendingFrame
        pendingFrame = nil
        deliveryScheduled = false
        return frame
    }
}

final class ScrollDisplayLinkDriver: NSObject {
    private let callback: (TimeInterval) -> Void
    private var lastTimestamp: TimeInterval?
    // Stored opaquely so the driver can retain macOS 13 deployment support
    // while using CADisplayLink on macOS 14 and newer.
    private var modernDisplayLink: AnyObject?
    private var legacyDisplayLink: CVDisplayLink?
    private let legacyFrameLock = NSLock()
    private var legacyFrameCoalescer = DisplayFrameCoalescer()

    init(callback: @escaping (TimeInterval) -> Void) {
        self.callback = callback
    }

    var isRunning: Bool {
        modernDisplayLink != nil || legacyDisplayLink != nil
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        lastTimestamp = nil

        if #available(macOS 14.0, *),
           let screen = screenUnderPointer ?? NSScreen.main ?? NSScreen.screens.first {
            let displayLink = screen.displayLink(
                target: self,
                selector: #selector(displayLinkDidFire(_:))
            )
            displayLink.add(to: .main, forMode: .common)
            modernDisplayLink = displayLink
            return true
        }

        return startLegacyDisplayLink()
    }

    func stop() {
        if #available(macOS 14.0, *),
           let displayLink = modernDisplayLink as? CADisplayLink {
            displayLink.invalidate()
        }
        modernDisplayLink = nil

        legacyFrameLock.lock()
        legacyFrameCoalescer.endSession()
        legacyFrameLock.unlock()
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

    private func startLegacyDisplayLink() -> Bool {
        var displayLink: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&displayLink) == kCVReturnSuccess,
              let displayLink else {
            return false
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard CVDisplayLinkSetOutputCallback(
            displayLink,
            { _, _, outputTime, _, _, context in
                guard let context else { return kCVReturnError }
                let driver = Unmanaged<ScrollDisplayLinkDriver>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                let timestamp = Double(outputTime.pointee.hostTime) / CVGetHostClockFrequency()
                driver.enqueueLegacyFrame(timestamp: timestamp)
                return kCVReturnSuccess
            },
            context
        ) == kCVReturnSuccess else {
            return false
        }

        guard CVDisplayLinkStart(displayLink) == kCVReturnSuccess else {
            return false
        }
        legacyDisplayLink = displayLink
        legacyFrameLock.lock()
        legacyFrameCoalescer.beginSession()
        legacyFrameLock.unlock()
        return true
    }

    private func enqueueLegacyFrame(timestamp: TimeInterval) {
        let frame = DisplayFrameSample(
            timestamp: timestamp,
            fallbackDuration: 1.0 / 60.0
        )
        legacyFrameLock.lock()
        let generation = legacyFrameCoalescer.enqueue(frame)
        legacyFrameLock.unlock()

        guard let generation else { return }
        DispatchQueue.main.async { [weak self] in
            self?.deliverPendingLegacyFrame(for: generation)
        }
    }

    private func deliverPendingLegacyFrame(for generation: UInt64) {
        legacyFrameLock.lock()
        let frame = legacyFrameCoalescer.takePending(for: generation)
        legacyFrameLock.unlock()
        guard let frame else { return }
        deliverFrame(
            timestamp: frame.timestamp,
            fallbackDuration: frame.fallbackDuration
        )
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
