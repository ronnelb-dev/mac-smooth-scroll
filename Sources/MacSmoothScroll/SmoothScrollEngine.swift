import ApplicationServices
import CoreGraphics
import Foundation

final class SmoothScrollEngine {
    private static let syntheticMarker: Int64 = 0x4D_53_53_43_52_4F_4C_4C

    private let settings: ScrollSettings
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private lazy var displayLink = ScrollDisplayLinkDriver { [weak self] elapsedTime in
        self?.animateFrame(elapsedTime: elapsedTime)
    }
    private var motion = ScrollMotionController()
    private var inputTransformer = ScrollInputTransformer()
    private var gestureActive = false
    private var gestureFlags: CGEventFlags = []

    init(settings: ScrollSettings) {
        self.settings = settings
    }

    func refresh() {
        guard settings.isEnabled else {
            stop()
            settings.engineMessage = "Smooth scrolling is off"
            return
        }
        guard !settings.competingDriverRunning else {
            stop()
            settings.engineMessage = "Paused while Mac Mouse Fix is running"
            return
        }
        guard settings.permissionGranted else {
            stop()
            settings.engineMessage = "Permission required"
            return
        }
        start()
    }

    func start() {
        guard eventTap == nil else {
            settings.engineMessage = "Smooth scrolling is active"
            return
        }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let engine = Unmanaged<SmoothScrollEngine>.fromOpaque(userInfo).takeUnretainedValue()
            return engine.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            settings.engineMessage = "Could not start. Check Accessibility and Input Monitoring."
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        settings.engineMessage = "Smooth scrolling is active"
    }

    func stop() {
        displayLink.stop()
        motion.reset()
        inputTransformer.reset()
        finishGestureIfNeeded()

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        // Preserve native trackpad and Magic Mouse input. Only discrete mouse-wheel
        // events are transformed.
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
            return Unmanaged.passUnretained(event)
        }

        ingest(event)
        return nil
    }

    private func ingest(_ event: CGEvent) {
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        let pointY = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let pointX = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))

        let result = inputTransformer.transform(
            ScrollInputSample(
                lineX: lineX,
                lineY: lineY,
                pointX: pointX,
                pointY: pointY,
                flags: event.flags,
                timestamp: ProcessInfo.processInfo.systemUptime
            ),
            using: settings.scrollTransformConfiguration
        )

        if result.beginsNewBurst {
            finishGestureIfNeeded()
            gestureFlags = result.outputFlags
        }
        if motion.add(result.impulse, feel: settings.feel) {
            finishGestureIfNeeded()
            gestureFlags = result.outputFlags
        }
        displayLink.start()
    }

    private func animateFrame(elapsedTime: TimeInterval) {
        let output = motion.step(
            elapsedTime: elapsedTime,
            decay: settings.smoothness.decay
        )
        if output.x != 0 || output.y != 0 {
            postScroll(x: output.x, y: output.y)
        }

        if output.finished {
            displayLink.stop()
            finishGestureIfNeeded()
        }
    }

    private func postScroll(x: Int32, y: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: y,
            wheel2: x,
            wheel3: 0
        ) else { return }

        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        // Modifier semantics are frozen for the physical wheel burst so releasing
        // a key cannot change an already-animating gesture tail.
        event.flags = gestureFlags

        if settings.trackpadSimulation {
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            let phase: CGScrollPhase = gestureActive ? .changed : .began
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            gestureActive = true
        }
        event.post(tap: .cgSessionEventTap)
    }

    private func finishGestureIfNeeded() {
        guard gestureActive else { return }
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticMarker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.ended.rawValue))
        event.flags = gestureFlags
        event.post(tap: .cgSessionEventTap)
        gestureActive = false
        gestureFlags = []
    }
}
