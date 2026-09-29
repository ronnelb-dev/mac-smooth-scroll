import AppKit
import CoreGraphics

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
        isEnabled: Bool = true
    ) -> Action? {
        guard isEnabled, event.type == .otherMouseDown else { return nil }
        switch event.getIntegerValueField(.mouseEventButtonNumber) {
        case 3: return .back
        case 4: return .forward
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
        bundleIdentifier: String?,
        sender: (Shortcut) -> Bool
    ) -> Bool {
        guard let action = action(for: event, isEnabled: isEnabled) else {
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
