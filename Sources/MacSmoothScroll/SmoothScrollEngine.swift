import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

struct ScrollOutputGate {
    private(set) var isAvailable = true

    @discardableResult
    mutating func record(_ succeeded: Bool) -> Bool {
        if !succeeded {
            isAvailable = false
        }
        return succeeded
    }

    mutating func restore() {
        isAvailable = true
    }
}

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
    private var automaticRecoveryPaused = false
    private let eventFilter = ScrollEventFilter()
    private let bypassPolicy = ScrollBypassPolicy()
    private var gestureLifecycle = ScrollGestureLifecycle()
    private var magnificationLifecycle = MagnificationLifecycle()
    private var magnificationEventFactory = MagnificationEventFactory()
    private var pageZoomController = PageZoomController()
    private let pageZoomShortcutResolver = PageZoomShortcutResolver()
    private let zoomOutputCapabilityResolver = ZoomOutputCapabilityResolver()
    private let chromiumClassifier = ChromiumBundleClassifier()
    private var activeOutput: ScrollTransformOutput?
    private var outputGate = ScrollOutputGate()

    init(settings: ScrollSettings) {
        self.settings = settings
    }

    func refresh() {
        refresh(isAutomaticRecovery: false)
    }

    func retry() {
        automaticRecoveryPaused = false
        recoveryPolicy.reset()
        refresh()
    }

    private func refresh(isAutomaticRecovery: Bool) {
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
        guard !automaticRecoveryPaused else {
            settings.engineStatus = .recoveryPaused
            return
        }
        start(isAutomaticRecovery: isAutomaticRecovery)
    }

    private func start(isAutomaticRecovery: Bool) {
        if let eventTap {
            if CGEvent.tapIsEnabled(tap: eventTap) {
                outputGate.restore()
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
            handleStartFailure(isAutomaticRecovery: isAutomaticRecovery)
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        if CGEvent.tapIsEnabled(tap: tap) {
            if isAutomaticRecovery {
                recoveryPolicy.didCompleteRebuild()
            } else {
                recoveryPolicy.reset()
            }
            outputGate.restore()
            settings.engineStatus = .active
        } else {
            tearDownEventTap()
            handleStartFailure(isAutomaticRecovery: isAutomaticRecovery)
        }
    }

    private func handleStartFailure(isAutomaticRecovery: Bool) {
        if isAutomaticRecovery {
            automaticRecoveryPaused = true
            settings.engineStatus = .recoveryPaused
        } else {
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
        automaticRecoveryPaused = false
        recoveryPolicy.reset()
        resetMotion()
        tearDownEventTap()
    }

    @discardableResult
    private func resetMotion() -> Bool {
        displayLink.stop()
        motion.reset()
        inputTransformer.reset()
        pageZoomController.reset()
        return finishActiveOutputIfNeeded()
    }

    private func abandonTransformedOutput() {
        displayLink.stop()
        motion.reset()
        inputTransformer.reset()
        pageZoomController.reset()
        gestureLifecycle.reset()
        magnificationLifecycle.reset()
        activeOutput = nil
    }

    private func failOpen() {
        outputGate.record(false)
        abandonTransformedOutput()
        settings.engineStatus = .outputFailed
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

        guard outputGate.isAvailable else {
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
            if !resetMotion() {
                failOpen()
            }
            return Unmanaged.passUnretained(event)
        }

        return ingest(event) ? nil : Unmanaged.passUnretained(event)
    }

    private func recoverEventTap(after reason: EventTapDisableReason) {
        guard !recoveryScheduled, !automaticRecoveryPaused else { return }
        settings.engineStatus = .recovering
        let action = recoveryPolicy.action(
            for: reason,
            at: ProcessInfo.processInfo.systemUptime
        )

        switch action {
        case .reenable:
            guard let eventTap else {
                recoverEventTap(after: .healthCheck)
                return
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
            if CGEvent.tapIsEnabled(tap: eventTap) {
                settings.engineStatus = .active
            } else {
                recoverEventTap(after: .healthCheck)
            }
        case .rebuild:
            scheduleEventTapRebuild()
        case .stop:
            pauseAutomaticRecovery()
        }
    }

    private func pauseAutomaticRecovery() {
        recoveryGeneration &+= 1
        recoveryScheduled = false
        automaticRecoveryPaused = true
        resetMotion()
        tearDownEventTap()
        settings.engineStatus = .recoveryPaused
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
            self.refresh(isAutomaticRecovery: true)
        }
    }

    private func ingest(_ event: CGEvent) -> Bool {
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        let pointY = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let pointX = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))

        let timestamp = ProcessInfo.processInfo.systemUptime
        let requestedConfiguration = settings.scrollTransformConfiguration
        let configuration = requestedConfiguration.replacingZoomBehavior(
            with: zoomOutputCapabilityResolver.effectiveBehavior(
                requested: requestedConfiguration.zoomBehavior,
                pinchEventsAvailable: magnificationEventFactory.isAvailable()
            )
        )
        let result = inputTransformer.transform(
            ScrollInputSample(
                lineX: lineX,
                lineY: lineY,
                pointX: pointX,
                pointY: pointY,
                flags: event.flags,
                timestamp: timestamp
            ),
            using: configuration
        )

        if result.beginsNewBurst {
            guard finishActiveOutputIfNeeded() else {
                failOpen()
                return false
            }
            prepareActiveOutput(result.output)
        }

        if case let .pageZoom(direction) = result.output {
            displayLink.stop()
            motion.reset()
            guard finishActiveOutputIfNeeded() else {
                failOpen()
                return false
            }
            if let command = pageZoomController.command(
                for: direction,
                at: timestamp,
                shortcuts: pageZoomShortcutResolver.resolveCurrentLayout()
            ) {
                guard outputGate.record(postPageZoom(command)) else {
                    failOpen()
                    return false
                }
            }
            return true
        }

        if activeOutput == nil {
            prepareActiveOutput(result.output)
        }
        if motion.add(
            result.impulse,
            feel: settings.feel,
            maximumVelocityMultiplier: result.velocityLimitMultiplier
        ) {
            guard finishActiveOutputIfNeeded() else {
                failOpen()
                return false
            }
            prepareActiveOutput(result.output)
        }
        guard outputGate.record(displayLink.start()) else {
            failOpen()
            return false
        }
        return true
    }

    private func animateFrame(elapsedTime: TimeInterval) {
        let output = motion.step(
            elapsedTime: elapsedTime,
            decay: settings.smoothness.decay
        )
        if output.x != 0 || output.y != 0 {
            let emitted: Bool
            switch activeOutput {
            case .pinchZoom:
                emitted = postMagnification(x: output.x, y: output.y)
            case .scroll:
                emitted = postScroll(x: output.x, y: output.y)
            case .pageZoom, nil:
                emitted = true
            }
            guard outputGate.record(emitted) else {
                failOpen()
                return
            }
        }

        if output.finished {
            displayLink.stop()
            guard finishActiveOutputIfNeeded() else {
                failOpen()
                return
            }
        }
    }

    private func postScroll(x: Int32, y: Int32) -> Bool {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: y,
            wheel2: x,
            wheel3: 0
        ) else { return false }

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
        return true
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

    @discardableResult
    private func finishActiveOutputIfNeeded() -> Bool {
        defer { activeOutput = nil }
        switch activeOutput {
        case .scroll:
            guard let emission = gestureLifecycle.finish() else { return true }
            return postScrollEnd(emission)
        case .pinchZoom:
            guard let descriptor = magnificationLifecycle.finish() else { return true }
            return postMagnification(descriptor)
        case .pageZoom, nil:
            return true
        }
    }

    private func postScrollEnd(_ emission: ScrollGestureEmission) -> Bool {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else { return false }

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
        return true
    }

    private func postMagnification(x: Int32, y: Int32) -> Bool {
        for descriptor in magnificationLifecycle.events(x: x, y: y) {
            guard postMagnification(descriptor) else { return false }
        }
        return true
    }

    private func postMagnification(_ descriptor: MagnificationEventDescriptor) -> Bool {
        guard let event = magnificationEventFactory.event(for: descriptor) else {
            return false
        }
        event.post(tap: .cghidEventTap)
        return true
    }

    private func postPageZoom(_ descriptor: PageZoomCommandDescriptor) -> Bool {
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: descriptor.keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: descriptor.keyCode,
            keyDown: false
        ) else { return false }

        keyDown.flags = descriptor.flags
        keyUp.flags = descriptor.flags
        let characters = Array(descriptor.characters.utf16)
        characters.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: buffer.baseAddress
            )
            keyUp.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: buffer.baseAddress
            )
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
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
