import Carbon.HIToolbox
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

struct ZoomOutputCapabilityResolver {
    func effectiveBehavior(
        requested: ZoomBehavior,
        pinchEventsAvailable: Bool
    ) -> ZoomBehavior {
        requested == .pinch && !pinchEventsAvailable ? .page : requested
    }
}

struct MagnificationEventFactory {
    private struct Schema {
        let eventType: CGEventType
        let gestureSubtypeField: CGEventField
        let magnificationField: CGEventField
        let phaseField: CGEventField
    }

    private static let eventTypeRawValue: UInt32 = 29
    private static let gestureSubtypeFieldRawValue: UInt32 = 110
    private static let magnificationFieldRawValue: UInt32 = 113
    private static let phaseFieldRawValue: UInt32 = 132
    private static let gestureSubtype: Int64 = 8

    private let allowsRuntimeEvents: Bool
    private var cachedAvailability: Bool?

    init(allowsRuntimeEvents: Bool = true) {
        self.allowsRuntimeEvents = allowsRuntimeEvents
    }

    mutating func isAvailable() -> Bool {
        if let cachedAvailability {
            return cachedAvailability
        }
        guard allowsRuntimeEvents,
              let schema = resolvedSchema(),
              let event = makeUncheckedEvent(
                  MagnificationEventDescriptor(
                      magnification: 0.125,
                      phase: .began
                  ),
                  schema: schema
              ),
              event.type.rawValue == Self.eventTypeRawValue,
              event.getIntegerValueField(schema.gestureSubtypeField)
                == Self.gestureSubtype,
              event.getIntegerValueField(schema.phaseField)
                == MagnificationPhase.began.rawValue,
              abs(event.getDoubleValueField(schema.magnificationField) - 0.125)
                < 0.000_001
        else {
            cachedAvailability = false
            return false
        }

        cachedAvailability = true
        return true
    }

    mutating func event(
        for descriptor: MagnificationEventDescriptor
    ) -> CGEvent? {
        guard isAvailable(),
              let schema = resolvedSchema(),
              let event = makeUncheckedEvent(descriptor, schema: schema)
        else {
            cachedAvailability = false
            return nil
        }
        return event
    }

    private func makeUncheckedEvent(
        _ descriptor: MagnificationEventDescriptor,
        schema: Schema
    ) -> CGEvent? {
        guard let event = CGEvent(source: nil) else { return nil }

        event.type = schema.eventType
        event.setIntegerValueField(
            schema.gestureSubtypeField,
            value: Self.gestureSubtype
        )
        event.setIntegerValueField(
            schema.phaseField,
            value: descriptor.phase.rawValue
        )
        event.setDoubleValueField(
            schema.magnificationField,
            value: descriptor.magnification
        )
        return event
    }

    private func resolvedSchema() -> Schema? {
        guard let eventType = CGEventType(rawValue: Self.eventTypeRawValue),
              let gestureSubtypeField = CGEventField(
                  rawValue: Self.gestureSubtypeFieldRawValue
              ),
              let magnificationField = CGEventField(
                  rawValue: Self.magnificationFieldRawValue
              ),
              let phaseField = CGEventField(rawValue: Self.phaseFieldRawValue)
        else {
            return nil
        }
        return Schema(
            eventType: eventType,
            gestureSubtypeField: gestureSubtypeField,
            magnificationField: magnificationField,
            phaseField: phaseField
        )
    }
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
    let characters: String
}

struct PageZoomShortcut: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let characters: String
}

struct PageZoomShortcutSet: Equatable {
    let zoomIn: PageZoomShortcut
    let zoomOut: PageZoomShortcut

    static let fallback = PageZoomShortcutSet(
        zoomIn: PageZoomShortcut(
            keyCode: CGKeyCode(kVK_ANSI_Equal),
            flags: .maskShift,
            characters: "+"
        ),
        zoomOut: PageZoomShortcut(
            keyCode: CGKeyCode(kVK_ANSI_Minus),
            flags: [],
            characters: "-"
        )
    )
}

struct KeyboardLayoutKeyCandidate: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let characters: String
}

final class PageZoomShortcutResolver {
    private static let numericKeypadKeyCodes: Set<CGKeyCode> = [
        65, 67, 69, 75, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92
    ]

    private var cachedSourceIdentifier: String?
    private var cachedShortcuts: PageZoomShortcutSet?

    func resolveCurrentLayout() -> PageZoomShortcutSet {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?
            .takeRetainedValue()
        else {
            return .fallback
        }

        let sourceIdentifier = inputSourceIdentifier(source)
        if let sourceIdentifier,
           sourceIdentifier == cachedSourceIdentifier,
           let cachedShortcuts {
            return cachedShortcuts
        }

        let shortcuts = resolve(candidates: currentLayoutCandidates(source))
        cachedSourceIdentifier = sourceIdentifier
        cachedShortcuts = sourceIdentifier == nil ? nil : shortcuts
        return shortcuts
    }

    func resolve(
        candidates: [KeyboardLayoutKeyCandidate]
    ) -> PageZoomShortcutSet {
        PageZoomShortcutSet(
            zoomIn: shortcut(for: "+", candidates: candidates)
                ?? PageZoomShortcutSet.fallback.zoomIn,
            zoomOut: shortcut(for: "-", candidates: candidates)
                ?? PageZoomShortcutSet.fallback.zoomOut
        )
    }

    private func shortcut(
        for characters: String,
        candidates: [KeyboardLayoutKeyCandidate]
    ) -> PageZoomShortcut? {
        let matchingCandidates = candidates.filter {
            $0.characters == characters
        }
        guard let candidate = matchingCandidates.min(by: {
            candidateScore($0) < candidateScore($1)
        }) else {
            return nil
        }
        return PageZoomShortcut(
            keyCode: candidate.keyCode,
            flags: candidate.flags,
            characters: characters
        )
    }

    private func candidateScore(_ candidate: KeyboardLayoutKeyCandidate) -> Int {
        let keypadPenalty = Self.numericKeypadKeyCodes.contains(candidate.keyCode)
            ? 10_000
            : 0
        let modifierPenalty = candidate.flags.rawValue.nonzeroBitCount * 1_000
        return keypadPenalty + modifierPenalty + Int(candidate.keyCode)
    }

    private func currentLayoutCandidates(
        _ source: TISInputSource
    ) -> [KeyboardLayoutKeyCandidate] {
        guard let property = TISGetInputSourceProperty(
                  source,
                  kTISPropertyUnicodeKeyLayoutData
              )
        else {
            return []
        }

        let layoutData = Unmanaged<CFData>
            .fromOpaque(property)
            .takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return [] }
        let layout = UnsafeRawPointer(bytes)
            .assumingMemoryBound(to: UCKeyboardLayout.self)

        let modifierStates: [(UInt32, CGEventFlags)] = [
            (0, []),
            (UInt32(shiftKey), .maskShift),
            (UInt32(optionKey), .maskAlternate),
            (UInt32(shiftKey | optionKey), [.maskShift, .maskAlternate])
        ]
        var candidates: [KeyboardLayoutKeyCandidate] = []
        for modifierState in modifierStates {
            for keyCode in CGKeyCode(0) ... CGKeyCode(127) {
                guard let characters = translatedCharacters(
                    layout: layout,
                    keyCode: keyCode,
                    carbonModifiers: modifierState.0
                ), characters == "+" || characters == "-"
                else {
                    continue
                }
                candidates.append(
                    KeyboardLayoutKeyCandidate(
                        keyCode: keyCode,
                        flags: modifierState.1,
                        characters: characters
                    )
                )
            }
        }
        return candidates
    }

    private func inputSourceIdentifier(_ source: TISInputSource) -> String? {
        guard let property = TISGetInputSourceProperty(
            source,
            kTISPropertyInputSourceID
        ) else {
            return nil
        }
        let identifier = Unmanaged<CFString>
            .fromOpaque(property)
            .takeUnretainedValue()
        return identifier as String
    }

    private func translatedCharacters(
        layout: UnsafePointer<UCKeyboardLayout>,
        keyCode: CGKeyCode,
        carbonModifiers: UInt32
    ) -> String? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = characters.withUnsafeMutableBufferPointer { buffer in
            UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDown),
                (carbonModifiers >> 8) & 0xFF,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                buffer.count,
                &length,
                buffer.baseAddress
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}

struct PageZoomController {
    static let minimumInterval = 0.1

    private var lastCommandTime: TimeInterval?

    mutating func command(
        for direction: PageZoomDirection?,
        at timestamp: TimeInterval,
        shortcuts: PageZoomShortcutSet = .fallback
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
                keyCode: shortcuts.zoomIn.keyCode,
                flags: shortcuts.zoomIn.flags.union(.maskCommand),
                characters: shortcuts.zoomIn.characters
            )
        case .zoomOut:
            return PageZoomCommandDescriptor(
                direction: direction,
                keyCode: shortcuts.zoomOut.keyCode,
                flags: shortcuts.zoomOut.flags.union(.maskCommand),
                characters: shortcuts.zoomOut.characters
            )
        }
    }

    mutating func reset() {
        lastCommandTime = nil
    }
}
