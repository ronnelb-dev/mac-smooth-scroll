# Mac Smooth Scroll Privacy Statement

Mac Smooth Scroll is designed to perform its work locally on the Mac.

## Data processing

The app observes discrete scroll-wheel events through a macOS Core Graphics
event tap. It uses the wheel deltas and active modifier flags to calculate and
post replacement pixel-scrolling events. When application exclusions are
configured, it compares the foreground application's bundle identifier with
the saved exclusion list to decide whether to pass the wheel event through.

This processing happens in memory. Mac Smooth Scroll does not save or transmit
raw wheel events, keyboard input, browsing activity, application content, or
mouse usage history.

## Local preferences

The following choices are stored locally with macOS `UserDefaults`:

- Whether smooth scrolling is enabled
- Smoothness, speed, scroll feel, and whether Minimum wheel step is enabled,
  including its saved distance
- Trackpad-like gestures, reverse scrolling, adaptive precision, and scroll
  acceleration
- Whether automatic axis locking is enabled
- Modifier assignments, including temporary smooth-scrolling bypass
- Names and bundle identifiers of applications the user excludes from smooth
  scrolling
- Menu-bar visibility
- Launch at Login preference and the last registered helper build
- Whether the first-run setup assistant has been completed
- The last selected Settings tab

These preferences use the app domain `com.ronnel.mac-smooth-scroll`. They can be
removed with:

```sh
defaults delete com.ronnel.mac-smooth-scroll
```

The helper build value is internal registration metadata used to repair Launch
at Login after an app update. It does not contain login history, account
identifiers, or device identifiers. These preferences and metadata remain local
and are not transmitted.

Application exclusions store only the displayed application name and bundle
identifier. Mac Smooth Scroll does not store application paths, usage history,
window titles, or the applications where scrolling occurred.

## Permissions

Accessibility permission allows the app to intercept and replace mouse-wheel
events. Mac Smooth Scroll checks this permission with the public macOS
Accessibility APIs.

The app does not use Accessibility permission to read application content or
record keyboard input. It checks only modifier flags attached to wheel events;
it does not install a global keyboard hook.

## Other applications

Mac Smooth Scroll checks whether processes with the Mac Mouse Fix application
or helper bundle identifiers are running. It uses only that running/not-running
state to pause its scroll engine and prevent two mouse drivers from processing
the same wheel input.

## Network activity

The current source contains no networking, analytics, telemetry, advertising,
account, cloud-sync, crash-upload, or automatic-update implementation.

If a future version adds network functionality, this statement and the
user-facing documentation should be updated before that version is released.
