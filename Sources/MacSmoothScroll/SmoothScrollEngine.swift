import ApplicationServices
import CoreGraphics
import Foundation

final class SmoothScrollEngine {
    private static let syntheticMarker: Int64 = 0x4D_53_53_43_52_4F_4C_4C

    private let settings: ScrollSettings
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var animationTimer: Timer?
    private var velocityX = 0.0
    private var velocityY = 0.0
    private var remainderX = 0.0
    private var remainderY = 0.0
    private var inputTransformer = ScrollInputTransformer()
    private var gestureActive = false

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
        animationTimer?.invalidate()
        animationTimer = nil
        velocityX = 0
        velocityY = 0
        remainderX = 0
        remainderY = 0
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

        let impulse = inputTransformer.transform(
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
        velocityX += impulse.x
        velocityY += impulse.y

        ensureAnimationTimer()
    }

    private func ensureAnimationTimer() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.animateTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func animateTick() {
        let decay = settings.smoothness.decay
        remainderX += velocityX
        remainderY += velocityY

        let outputX = Int32(remainderX.rounded(.towardZero))
        let outputY = Int32(remainderY.rounded(.towardZero))
        remainderX -= Double(outputX)
        remainderY -= Double(outputY)

        if outputX != 0 || outputY != 0 {
            postScroll(x: outputX, y: outputY)
        }

        velocityX *= decay
        velocityY *= decay

        if abs(velocityX) < 0.025,
           abs(velocityY) < 0.025,
           abs(remainderX) < 0.5,
           abs(remainderY) < 0.5 {
            animationTimer?.invalidate()
            animationTimer = nil
            velocityX = 0
            velocityY = 0
            remainderX = 0
            remainderY = 0
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
        // Current modifier flags are carried onto the synthetic event so apps with
        // modifier-scroll zoom support receive their native shortcut.
        event.flags = CGEventSource.flagsState(.combinedSessionState)

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
        event.post(tap: .cgSessionEventTap)
        gestureActive = false
    }
}
