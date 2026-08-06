import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

final class SmoothScrollEngine {
    private let settings: ScrollSettings
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private lazy var displayLink = ScrollDisplayLinkDriver { [weak self] elapsedTime in
        self?.animateFrame(elapsedTime: elapsedTime)
    }
    private var motion = ScrollMotionController()
    private var inputTransformer = ScrollInputTransformer()
    private var recoveryPolicy = EventTapRecoveryPolicy()
    private var recoveryGeneration = 0
    private var recoveryScheduled = false
    private let eventFilter = ScrollEventFilter()
    private let bypassPolicy = ScrollBypassPolicy()
    private var gestureLifecycle = ScrollGestureLifecycle()
    private var magnificationLifecycle = MagnificationLifecycle()
    private var pageZoomController = PageZoomController()
    private let chromiumClassifier = ChromiumBundleClassifier()
    private var activeOutput: ScrollTransformOutput?

    init(settings: ScrollSettings) {
        self.settings = settings
    }

    func refresh() {
        guard settings.isEnabled else {
            stop()
            settings.engineStatus = .disabled
            return
        }
        guard !settings.competingDriverRunning else {
            stop()
            settings.engineStatus = .driverConflict
            return
        }
        guard settings.permissionGranted else {
            stop()
            settings.engineStatus = .permissionBlocked
            return
        }
        start()
    }

    func start() {
        if let eventTap {
            if CGEvent.tapIsEnabled(tap: eventTap) {
                settings.engineStatus = .active
            } else {
                scheduleEventTapRebuild()
            }
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
            settings.engineStatus = .startFailed
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        if CGEvent.tapIsEnabled(tap: tap) {
            recoveryPolicy.reset()
            settings.engineStatus = .active
        } else {
            tearDownEventTap()
            settings.engineStatus = .startFailed
        }
    }

    func auditHealth() {
        guard settings.isEnabled,
              settings.permissionGranted,
              !settings.competingDriverRunning,
              let eventTap
        else {
            return
        }

        if CGEvent.tapIsEnabled(tap: eventTap) {
            if settings.engineStatus == .recovering {
                settings.engineStatus = .active
            }
        } else {
            recoverEventTap(after: .healthCheck)
        }
    }

    func stop() {
        recoveryGeneration &+= 1
        recoveryScheduled = false
        recoveryPolicy.reset()
        resetMotion()
        tearDownEventTap()
    }

    private func resetMotion() {
        displayLink.stop()
        motion.reset()
        inputTransformer.reset()
        pageZoomController.reset()
        finishActiveOutputIfNeeded()
    }

    private func tearDownEventTap() {
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
            recoverEventTap(
                after: type == .tapDisabledByTimeout ? .timeout : .userInput
            )
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        let disposition = eventFilter.disposition(
            sourceUserData: event.getIntegerValueField(.eventSourceUserData),
            isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        )
        guard disposition == .transform else {
            return Unmanaged.passUnretained(event)
        }

        if bypassPolicy.shouldBypass(
            flags: event.flags,
            modifier: settings.bypassModifier,
            frontmostBundleIdentifier:
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            excludedBundleIdentifiers:
                settings.excludedApplicationBundleIdentifiers
        ) {
            resetMotion()
            return Unmanaged.passUnretained(event)
        }

        ingest(event)
        return nil
    }

    private func recoverEventTap(after reason: EventTapDisableReason) {
        settings.engineStatus = .recovering
        let action = recoveryPolicy.action(
            for: reason,
            at: ProcessInfo.processInfo.systemUptime
        )

        switch action {
        case .reenable:
            guard let eventTap else {
                scheduleEventTapRebuild()
                return
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            if CGEvent.tapIsEnabled(tap: eventTap) {
                settings.engineStatus = .active
            } else {
                scheduleEventTapRebuild()
            }
        case .rebuild:
            scheduleEventTapRebuild()
        }
    }

    private func scheduleEventTapRebuild() {
        guard !recoveryScheduled else { return }
        settings.engineStatus = .recovering
        recoveryScheduled = true
        recoveryGeneration &+= 1
        let generation = recoveryGeneration

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.recoveryScheduled,
                  self.recoveryGeneration == generation
            else {
                return
            }

            self.recoveryScheduled = false
            self.resetMotion()
            self.tearDownEventTap()
            self.recoveryPolicy.reset()
            self.refresh()
        }
    }

    private func ingest(_ event: CGEvent) {
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        let pointY = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let pointX = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))

        let timestamp = ProcessInfo.processInfo.systemUptime
        let result = inputTransformer.transform(
            ScrollInputSample(
                lineX: lineX,
                lineY: lineY,
                pointX: pointX,
                pointY: pointY,
                flags: event.flags,
                timestamp: timestamp
            ),
            using: settings.scrollTransformConfiguration
        )

        if result.beginsNewBurst {
            finishActiveOutputIfNeeded()
            prepareActiveOutput(result.output)
        }

        if case let .pageZoom(direction) = result.output {
            displayLink.stop()
            motion.reset()
            finishActiveOutputIfNeeded()
            if let command = pageZoomController.command(
                for: direction,
                at: timestamp
            ) {
                postPageZoom(command)
            }
            return
        }

        if activeOutput == nil {
            prepareActiveOutput(result.output)
        }
        if motion.add(
            result.impulse,
            feel: settings.feel,
            maximumVelocityMultiplier: result.velocityLimitMultiplier
        ) {
            finishActiveOutputIfNeeded()
            prepareActiveOutput(result.output)
        }
        displayLink.start()
    }

    private func animateFrame(elapsedTime: TimeInterval) {
        let output = motion.step(
            elapsedTime: elapsedTime,
            decay: settings.smoothness.decay
        )
        if output.x != 0 || output.y != 0 {
            switch activeOutput {
            case .pinchZoom:
                postMagnification(x: output.x, y: output.y)
            case .scroll:
                postScroll(x: output.x, y: output.y)
            case .pageZoom, nil:
                break
            }
        }

        if output.finished {
            displayLink.stop()
            finishActiveOutputIfNeeded()
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

        event.setIntegerValueField(
            .eventSourceUserData,
            value: ScrollEventFilter.syntheticMarker
        )
        if let emission = gestureLifecycle.phaseForOutput(
            trackpadSimulation: settings.trackpadSimulation
        ) {
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.setIntegerValueField(
                .scrollWheelEventScrollPhase,
                value: Int64(cgPhase(for: emission.phase).rawValue)
            )
            event.flags = emission.flags
        } else {
            // Modifier semantics are frozen for the physical wheel burst so
            // releasing a key cannot change an already-animating gesture tail.
            event.flags = gestureLifecycle.outputFlags
        }
        event.post(tap: .cgSessionEventTap)
    }

    private func prepareActiveOutput(_ output: ScrollTransformOutput) {
        switch output {
        case let .scroll(flags):
            gestureLifecycle.prepareForBurst(flags: flags)
            activeOutput = output
        case .pinchZoom:
            magnificationLifecycle.prepareForBurst(
                isChromium: chromiumClassifier.matches(
                    NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                )
            )
            activeOutput = output
        case .pageZoom:
            activeOutput = nil
        }
    }

    private func finishActiveOutputIfNeeded() {
        defer { activeOutput = nil }
        switch activeOutput {
        case .scroll:
            guard let emission = gestureLifecycle.finish() else { return }
            postScrollEnd(emission)
        case .pinchZoom:
            guard let descriptor = magnificationLifecycle.finish() else { return }
            postMagnification(descriptor)
        case .pageZoom, nil:
            break
        }
    }

    private func postScrollEnd(_ emission: ScrollGestureEmission) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        event.setIntegerValueField(
            .eventSourceUserData,
            value: ScrollEventFilter.syntheticMarker
        )
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(
            .scrollWheelEventScrollPhase,
            value: Int64(cgPhase(for: emission.phase).rawValue)
        )
        event.flags = emission.flags
        event.post(tap: .cgSessionEventTap)
    }

    private func postMagnification(x: Int32, y: Int32) {
        for descriptor in magnificationLifecycle.events(x: x, y: y) {
            postMagnification(descriptor)
        }
    }

    private func postMagnification(_ descriptor: MagnificationEventDescriptor) {
        guard let event = CGEvent(source: nil) else { return }
        event.type = CGEventType(rawValue: 29)!
        event.setIntegerValueField(
            CGEventField(rawValue: 110)!,
            value: 8
        )
        event.setIntegerValueField(
            CGEventField(rawValue: 132)!,
            value: descriptor.phase.rawValue
        )
        event.setDoubleValueField(
            CGEventField(rawValue: 113)!,
            value: descriptor.magnification
        )
        event.post(tap: .cghidEventTap)
    }

    private func postPageZoom(_ descriptor: PageZoomCommandDescriptor) {
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: descriptor.keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: descriptor.keyCode,
            keyDown: false
        ) else { return }

        keyDown.flags = descriptor.flags
        keyUp.flags = descriptor.flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func cgPhase(for phase: ScrollGesturePhase) -> CGScrollPhase {
        switch phase {
        case .began:
            .began
        case .changed:
            .changed
        case .ended:
            .ended
        }
    }
}
