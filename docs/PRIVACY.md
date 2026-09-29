# Mac Smooth Scroll Privacy Statement

Mac Smooth Scroll is designed to perform its work locally on the Mac.

## Data processing

The app observes discrete scroll-wheel events through a macOS Core Graphics
event tap. It uses the wheel deltas and active modifier flags to calculate and
post replacement pixel-scrolling events. When application exclusions are
configured, it compares the foreground application's bundle identifier with
the saved exclusion list to decide whether to pass the wheel event through.
It uses the same bundle identifier comparison to select an explicitly saved
application profile when one is enabled.

When Back and Forward buttons are enabled, the app reads the foreground
application's bundle identifier in memory to choose a compatible navigation
shortcut. It does not retain foreground-application history.

This processing happens in memory. Mac Smooth Scroll does not save or transmit
raw wheel events, keyboard input, browsing activity, application content, or
mouse usage history.

When the user explicitly starts Mouse Calibration, the app temporarily keeps
up to 24 physical wheel samples in memory. It uses only event timing,
continuous/discrete classification, axis dominance, and wheel-distance
magnitudes to recommend existing Minimum wheel step settings. The samples are
discarded when calibration finishes or is cancelled. The result, raw samples,
device identity, and mouse model are not written to `UserDefaults` or included
in Copy Diagnostics. Settings change only if the user selects **Apply
Recommendation**.

## Local preferences

The following choices are stored locally with macOS `UserDefaults`:

- Whether smooth scrolling is enabled
- Smoothness, speed, scroll feel, and whether Minimum wheel step is enabled,
  including its saved distance and multiplier preset
- Trackpad-like gestures, reverse scrolling, adaptive precision, short-burst
  scroll acceleration, and long-distance boost
- Whether automatic axis locking is enabled
- Modifier assignments, Zoom behavior, and temporary smooth-scrolling bypass
- Whether Back and Forward mouse buttons are enabled
- Names and bundle identifiers of applications the user excludes from smooth
  scrolling
- Names, bundle identifiers, enabled state, and copied scrolling choices for
  application-specific profiles
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

Application profiles and exclusions store only the displayed application name,
bundle identifier, and explicitly configured scrolling choices. Profile
selection compares the current foreground bundle identifier in memory. Mac
Smooth Scroll does not store application paths, foreground-app history, usage
history, window titles, or the applications where scrolling occurred.

**Copy Diagnostics** includes the app bundle identifier and reports its
location only as **Applications** or **Other location**. It does not copy the
filesystem path.

## Permissions

Accessibility permission allows the app to intercept and replace mouse-wheel
events and, when enabled, translate auxiliary mouse buttons into navigation
shortcuts. Mac Smooth Scroll checks this permission with the public macOS
Accessibility APIs.

The app does not use Accessibility permission to read application content or
record keyboard input. It checks only modifier flags attached to wheel events
and button numbers attached to auxiliary mouse events; it does not install a
global keyboard hook. Back and Forward posts only the documented navigation
shortcut selected for the foreground app. Page zoom reads the active macOS
keyboard-layout definition to locate the `+` and `-` shortcuts. It does not
read, store, or transmit typed characters or keyboard activity.

## Other applications

Mac Smooth Scroll compares the bundle identifiers of currently running
applications with a small built-in list for Mac Mouse Fix, LinearMouse, and
Mos. It uses Mac Mouse Fix's running/not-running state to pause its scroll
engine. LinearMouse and Mos produce advisory guidance only. The app does not
retain running-application history, store paths, inspect application content,
or include detected utility names in Copy Diagnostics.

## Network activity

The current source contains no networking, analytics, telemetry, advertising,
account, cloud-sync, crash-upload, or automatic-update implementation.

Selecting **Check for Updates…** asks macOS to open the project's public
GitHub Releases page in the default browser. The app does not make the network
request, receive release information, download a build, or install an update;
the browser and GitHub apply their own privacy policies to that page.

If a future version adds network functionality, this statement and the
user-facing documentation should be updated before that version is released.
