<p align="center">
  <img src="Resources/Brand/MacSmoothScrollIcon.png" width="160" alt="Mac Smooth Scroll icon">
</p>

# Mac Smooth Scroll

[![Apple Silicon CI](https://github.com/ronnelb-dev/mac-smooth-scroll/actions/workflows/ci.yml/badge.svg)](https://github.com/ronnelb-dev/mac-smooth-scroll/actions/workflows/ci.yml)

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

## Installation

Mac Smooth Scroll is currently distributed as source code. There is no
notarized public download yet.

1. Install the Xcode command-line tools:

   ```sh
   xcode-select --install
   ```

2. Clone and build the project:

   ```sh
   git clone https://github.com/ronnelb-dev/mac-smooth-scroll.git
   cd mac-smooth-scroll
   ./Scripts/build-app.sh
   ```

3. Move `dist/Mac Smooth Scroll.app` to `/Applications` before enabling
   Accessibility or Launch at Login.
4. Open the app from `/Applications`.

Confirm that the build machine is Apple Silicon with `uname -m`. The output
should be `arm64`.

The local build is ad-hoc signed. It is intended for use on the Mac that built
it and is not a substitute for Developer ID signing and Apple notarization.

## First launch and Accessibility

Mac Smooth Scroll uses a Core Graphics event tap to replace discrete external
mouse-wheel events with smooth pixel scrolling. macOS requires Accessibility
permission for this.

1. Open Mac Smooth Scroll.
2. Select **Request Permission**.
3. In **System Settings → Privacy & Security → Accessibility**, enable
   **Mac Smooth Scroll**.
4. Return to the app. Its status should change to
   **Smooth scrolling is active**.

Input Monitoring is not normally required by the app's permission check. If
Accessibility is already enabled but the app still reports that permission is
required, follow the [permission troubleshooting steps](docs/TROUBLESHOOTING.md#accessibility-is-enabled-but-the-app-still-asks-for-permission).

## Using the app

- Use **Smoothness** to control how gradually wheel movement decays.
- Use **Speed** to scale normal wheel movement.
- Enable **Trackpad simulation** to add gesture phases used by natural
  scrolling and horizontal navigation.
- Enable **Reverse direction** to reverse only external mouse scrolling.
- Enable **Adaptive precision** to reduce movement from slow, isolated wheel
  steps.
- Assign modifiers for horizontal, zoom, swift, and precise scrolling.

Trackpad and Magic Mouse events are passed through unchanged. Zoom behavior
depends on whether the active app supports modifier-scroll zooming.

## Menu-bar mode

Choose **Hide to Menu Bar**, close the settings window, or press `⌘H` to keep
smooth scrolling active without a Dock icon. Use **Open Mac Smooth Scroll…**
from the menu-bar item—or open the app again—to restore Settings.

Hiding the app automatically enables **Show in menu bar** so there is always a
way to reopen Settings or quit. The menu-bar item can also turn smooth
scrolling on or off while the window is hidden.

## Launch at login

Install the app in `/Applications` before enabling **Launch at login**. The
embedded login helper starts the main app with `--background`, so scrolling
continues with no settings window or Dock icon.

If macOS requests approval, open **System Settings → General → Login Items** and
allow Mac Smooth Scroll. Disable **Launch at login** inside the app before
moving or deleting the application.

## Privacy

Mac Smooth Scroll processes wheel events locally. The current source contains
no networking, analytics, telemetry, advertising, account, cloud-sync, or
automatic-update code. It does not save or transmit raw wheel events or
keyboard input.

Preferences are stored locally with macOS `UserDefaults`. The app checks only
whether Mac Mouse Fix is running, by bundle identifier, so it can pause and
avoid duplicate mouse processing. See the complete [privacy statement](docs/PRIVACY.md).

## Troubleshooting

See [Troubleshooting Mac Smooth Scroll](docs/TROUBLESHOOTING.md) for help with:

- Accessibility permission that is already enabled but not detected
- Smooth scrolling that does not start
- Conflicts with Mac Mouse Fix or another mouse utility
- A missing Dock or menu-bar icon
- Launch at Login approval
- Permission prompts after rebuilding the app

## Uninstall

1. Open Mac Smooth Scroll and disable **Launch at login**.
2. Choose **Quit Mac Smooth Scroll** from its menu-bar item.
3. Move `/Applications/Mac Smooth Scroll.app` to the Trash.
4. Remove Mac Smooth Scroll from
   **System Settings → Privacy & Security → Accessibility**.
5. Optionally remove saved preferences:

   ```sh
   defaults delete com.ronnel.mac-smooth-scroll
   ```

## Known limitations

- Apple Silicon and macOS 13 or later are required.
- There is no notarized public binary yet; users build the app from source.
- Settings are global; per-app and per-mouse profiles are not implemented.
- Other mouse drivers can duplicate or distort wheel input. Mac Mouse Fix is
  detected automatically, but other utilities may need to be quit manually.
- Ad-hoc rebuilds can require Accessibility permission to be approved again.

## Build and signing

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

## Tests

Run the XCTest suite on Apple Silicon with:

```sh
swift test --arch arm64
```

The tests cover launch-mode parsing, settings defaults and persistence,
modifier behavior, and the scroll-input transformation rules used by the
runtime engine. GitHub Actions runs the suite before packaging every pull
request and `main` update.

## Roadmap

See [ROADMAP.md](ROADMAP.md) and the
[v0.3.0 milestone](https://github.com/ronnelb-dev/mac-smooth-scroll/milestone/1)
for the prioritized reliability work and future backlog.

## Development notes

The app uses an independent Swift implementation built with public macOS APIs:
SwiftUI/AppKit for settings and Core Graphics for wheel event capture and
synthetic pixel scrolling. It is not a renamed build of Mac Mouse Fix.

Mac Mouse Fix is an excellent independent project and was used as behavioral
inspiration. No Mac Mouse Fix source files are included in this repository.

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before
opening a pull request. Report suspected vulnerabilities according to
[SECURITY.md](SECURITY.md), not through a public issue.

## License

Mac Smooth Scroll is licensed under the
[GNU General Public License v3.0](LICENSE).
