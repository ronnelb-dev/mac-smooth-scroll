import AppKit
import CoreGraphics

struct MouseButtonAssignments: Equatable {
    static let supportedButtonNumbers = 3...31
    static let defaults = MouseButtonAssignments(uncheckedBack: 3, forward: 4)

    let backButtonNumber: Int64
    let forwardButtonNumber: Int64

    init?(backButtonNumber: Int64, forwardButtonNumber: Int64) {
        guard Self.supportedButtonNumbers.contains(Int(backButtonNumber)),
              Self.supportedButtonNumbers.contains(Int(forwardButtonNumber)),
              backButtonNumber != forwardButtonNumber
        else { return nil }
        self.backButtonNumber = backButtonNumber
        self.forwardButtonNumber = forwardButtonNumber
    }

    static func resolved(
        backButtonNumber: Int64?,
        forwardButtonNumber: Int64?
    ) -> MouseButtonAssignments {
        guard let backButtonNumber, let forwardButtonNumber else {
            return .defaults
        }
        return MouseButtonAssignments(
            backButtonNumber: backButtonNumber,
            forwardButtonNumber: forwardButtonNumber
        ) ?? .defaults
    }

    private init(uncheckedBack: Int64, forward: Int64) {
        backButtonNumber = uncheckedBack
        forwardButtonNumber = forward
    }
}

enum MouseButtonCaptureState: Equatable {
    case idle
    case awaitingBack
    case awaitingForward(backButtonNumber: Int64, validationMessage: String?)
    case completed(MouseButtonAssignments)
    case cancelled

    var isCapturing: Bool {
        switch self {
        case .awaitingBack, .awaitingForward: true
        case .idle, .completed, .cancelled: false
        }
    }
}

struct MouseButtonCaptureSession {
    private(set) var state: MouseButtonCaptureState = .idle

    mutating func start() {
        state = .awaitingBack
    }

    mutating func cancel() {
        state = .cancelled
    }

    @discardableResult
    mutating func capture(buttonNumber: Int64) -> Bool {
        guard MouseButtonAssignments.supportedButtonNumbers.contains(
            Int(buttonNumber)
        ) else { return false }

        switch state {
        case .awaitingBack:
            state = .awaitingForward(
                backButtonNumber: buttonNumber,
                validationMessage: nil
            )
            return true
        case let .awaitingForward(backButtonNumber, _):
            guard buttonNumber != backButtonNumber else {
                state = .awaitingForward(
                    backButtonNumber: backButtonNumber,
                    validationMessage:
                        "Choose a different button for Forward."
                )
                return true
            }
            guard let assignments = MouseButtonAssignments(
                backButtonNumber: backButtonNumber,
                forwardButtonNumber: buttonNumber
            ) else { return false }
            state = .completed(assignments)
            return true
        case .idle, .completed, .cancelled:
            return false
        }
    }
}

struct MouseButtonConsumptionTracker {
    private var buttonNumbers: Set<Int64> = []

    var isEmpty: Bool { buttonNumbers.isEmpty }

    mutating func record(_ buttonNumber: Int64) {
        buttonNumbers.insert(buttonNumber)
    }

    mutating func consumeRelease(for event: CGEvent) -> Bool {
        guard event.type == .otherMouseUp else { return false }
        return buttonNumbers.remove(
            event.getIntegerValueField(.mouseEventButtonNumber)
        ) != nil
    }

    mutating func reset() {
        buttonNumbers.removeAll()
    }
}

/// Translates the standard auxiliary mouse buttons into macOS navigation
/// shortcuts. The shortcuts are understood by browsers, Finder, Preview,
/// editors and many other Cocoa apps.
struct BackForwardButtonHandler {
    enum Action: Equatable { case back, forward }

    enum ShortcutProfile: Equatable {
        case standard
        case codeEditor
        case acrobat
    }

    struct Shortcut: Equatable {
        let keyCode: CGKeyCode
        let flags: CGEventFlags
    }

    static func action(
        for event: CGEvent,
        isEnabled: Bool = true,
        assignments: MouseButtonAssignments = .defaults
    ) -> Action? {
        guard isEnabled, event.type == .otherMouseDown else { return nil }
        switch event.getIntegerValueField(.mouseEventButtonNumber) {
        case assignments.backButtonNumber: return .back
        case assignments.forwardButtonNumber: return .forward
        default: return nil
        }
    }

    static func profile(for bundleIdentifier: String?) -> ShortcutProfile {
        guard let bundleIdentifier else { return .standard }

        let codeEditorIdentifierPrefixes = [
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.vscodium",
            "com.exafunction.windsurf",
            "com.codeium.windsurf",
            "dev.zed.Zed"
        ]
        if codeEditorIdentifierPrefixes.contains(where: {
            bundleIdentifier.hasPrefix($0)
        }) {
            return .codeEditor
        }

        if bundleIdentifier.hasPrefix("com.adobe.Acrobat") ||
            bundleIdentifier.hasPrefix("com.adobe.Reader") {
            return .acrobat
        }

        return .standard
    }

    static func shortcut(
        for action: Action,
        bundleIdentifier: String?
    ) -> Shortcut {
        switch (profile(for: bundleIdentifier), action) {
        case (.codeEditor, .back):
            // VS Code-family editors use Control-minus for Go Back.
            return Shortcut(keyCode: 27, flags: .maskControl)
        case (.codeEditor, .forward):
            // The forward command adds Shift to Control-minus.
            return Shortcut(
                keyCode: 27,
                flags: [.maskControl, .maskShift]
            )
        case (.acrobat, .back):
            return Shortcut(keyCode: 123, flags: .maskCommand)
        case (.acrobat, .forward):
            return Shortcut(keyCode: 124, flags: .maskCommand)
        case (.standard, .back), (.standard, .forward):
            return Shortcut(
                keyCode: action == .back ? 33 : 30,
                flags: .maskCommand
            )
        }
    }

    static func dispatch(
        event: CGEvent,
        isEnabled: Bool,
        assignments: MouseButtonAssignments = .defaults,
        bundleIdentifier: String?,
        sender: (Shortcut) -> Bool
    ) -> Bool {
        guard let action = action(
            for: event,
            isEnabled: isEnabled,
            assignments: assignments
        ) else {
            return false
        }
        return sender(
            shortcut(for: action, bundleIdentifier: bundleIdentifier)
        )
    }

    @discardableResult
    static func send(
        _ action: Action,
        bundleIdentifier: String? = nil
    ) -> Bool {
        send(shortcut(for: action, bundleIdentifier: bundleIdentifier))
    }

    @discardableResult
    static func send(_ shortcut: Shortcut) -> Bool {
        guard let down = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shortcut.keyCode,
            keyDown: true
        ),
        let up = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shortcut.keyCode,
            keyDown: false
        )
        else { return false }
        down.flags = shortcut.flags
        up.flags = shortcut.flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
