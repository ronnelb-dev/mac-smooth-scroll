<p align="center">
  <img src="Resources/Brand/MacSmoothScrollIcon.png" width="160" alt="Mac Smooth Scroll icon">
</p>

# Mac Smooth Scroll

Mac Smooth Scroll is a native Apple Silicon macOS utility that turns discrete
external mouse-wheel input into smooth pixel scrolling while leaving native
trackpad and Magic Mouse events untouched.

![Mac Smooth Scroll settings](docs/settings.png)

## Features

- Low, medium, and high smoothness presets
- Slow, medium, and fast speed presets
- Optional trackpad-style gesture phases
- External-mouse-only reverse direction
- Adaptive precision for slow wheel movement
- Configurable horizontal, zoom, swift, and precision modifier keys
- Menu-bar control
- Hide-to-menu-bar mode that removes the settings window and Dock icon
- Background-only launch at login with a dedicated helper
- Native Accessibility permission onboarding
- Automatic pause while Mac Mouse Fix is running to prevent conflicting input

## Requirements

- Apple Silicon Mac
- macOS 13 or later
- Xcode command-line tools
- Accessibility permission

## Build

```sh
./Scripts/build-app.sh
```

The resulting application is written to:

```text
dist/Mac Smooth Scroll.app
```

## Menu-bar mode

Choose **Hide to Menu Bar**, close the settings window, or press `⌘H` to keep
smooth scrolling active without a Dock icon. Use **Open Mac Smooth Scroll…**
from the menu-bar item—or open the app again—to restore Settings. When Launch
at Login is enabled, the embedded launcher starts the app directly in this
background mode.

The build script signs ad-hoc by default and never selects a certificate from
your Keychain automatically. To opt in to certificate signing, explicitly set
`MAC_SMOOTH_SCROLL_SIGNING_IDENTITY` to the identity you want to use:

```sh
MAC_SMOOTH_SCROLL_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
    ./Scripts/build-app.sh
```

Certificate-signed builds use the hardened runtime and a secure timestamp.
Distribution to other Macs still requires an Apple Developer ID Application
certificate and notarization. Ad-hoc local rebuilds may require Accessibility
permission to be approved again.

## Development notes

The app uses an independent Swift implementation built with public macOS APIs:
SwiftUI/AppKit for settings and Core Graphics for wheel event capture and
synthetic pixel scrolling. It is not a renamed build of Mac Mouse Fix.

Mac Mouse Fix is an excellent independent project and was used as behavioral
inspiration. No Mac Mouse Fix source files are included in this repository.

## License

Mac Smooth Scroll is licensed under the
[GNU General Public License v3.0](LICENSE).
