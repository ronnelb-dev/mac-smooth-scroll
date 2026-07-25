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
- Launch at login
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

The build script uses the first available Apple Development signing identity so
that macOS privacy permissions remain stable across local rebuilds. Set
`MAC_SMOOTH_SCROLL_SIGNING_IDENTITY` to choose a different identity. If no
development identity is available, the script falls back to ad-hoc signing.
Distribution to other Macs still requires an Apple Developer ID Application
certificate and notarization.

## Development notes

The app uses an independent Swift implementation built with public macOS APIs:
SwiftUI/AppKit for settings and Core Graphics for wheel event capture and
synthetic pixel scrolling. It is not a renamed build of Mac Mouse Fix.

Mac Mouse Fix is an excellent independent project and was used as behavioral
inspiration. No Mac Mouse Fix source files are included in this repository.

## License

No software license has been selected yet.
