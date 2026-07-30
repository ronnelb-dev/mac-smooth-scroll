# Manual macOS Regression Checklist

Use this checklist for behavior that XCTest and headless GitHub Actions cannot
verify. Run the relevant sections before merging changes that affect scrolling,
permissions, Settings, menu-bar mode, the login helper, packaging, or another
mouse utility.

Do not interpret an untested case as passing. Mark every case **Pass**,
**Fail**, **Blocked**, or **Not run**.

## Test record

Record enough context to reproduce hardware-specific behavior:

| Field | Result |
| --- | --- |
| Date | |
| App version and build | |
| Git commit | |
| Install source | Local app / local DMG / CI artifact / preview release |
| Signature | Ad-hoc / Developer ID |
| macOS version and build | |
| Apple Silicon model | M1 / M2 / M3 / M4 / later |
| Display refresh rate | 60 Hz / 120 Hz / other |
| External mouse model | |
| Wheel type | Notched / free-spinning / other |
| Native input tested | Trackpad / Magic Mouse / neither |
| Other mouse utilities | None / names and versions |

Do not record a username, computer name, serial number, hardware UUID, device
identifier, certificate, private key, Accessibility database export, raw mouse
activity, or unrelated filesystem path. Crop personal information from
screenshots.

## Preparation

- [ ] Install the test build in `/Applications`.
- [ ] Confirm only one copy of Mac Smooth Scroll is running.
- [ ] Keep a discrete external-wheel mouse connected.
- [ ] Keep a trackpad or Magic Mouse available when testing native pass-through.
- [ ] Note existing modifier assignments and app preferences before reset tests.
- [ ] Use a disposable macOS test account for a truly fresh setup when possible.

Permission revocation and Launch at Login tests change macOS state. Do not run
those sections during work you cannot safely interrupt.

## A. Installation and foreground launch

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| A1 | Open the DMG and drag Mac Smooth Scroll to Applications. | The copy completes and the app exists in `/Applications`. | |
| A2 | Launch the app normally from Applications. | One Settings window opens, the Dock icon is visible, and the app does not start hidden. | |
| A3 | Open the app again from Finder while it is running. | The existing Settings window becomes active; no duplicate window or process appears. | |
| A4 | On a fresh test account, launch before setup has been completed. | The setup assistant appears on an ordinary foreground launch. | |
| A5 | Select **Finish Later**, quit, and launch normally again. | Setup returns because completion was not saved. | |
| A6 | Complete setup, then use **App → Run Setup Again…**. | Setup stays completed but can be presented manually. | |

## B. Accessibility permission and recovery

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| B1 | Launch without Accessibility approval. | System Health reports **Permission required** and the engine reports **Permission blocked**. | |
| B2 | Select **Request Permission**, then enable Mac Smooth Scroll under **Privacy & Security → Accessibility**. | The app detects approval without requiring Input Monitoring and changes to **Ready** / **Active**. | |
| B3 | Revoke Accessibility while the app is running. | The engine stops transforming events and reports the permission problem within a few seconds. | |
| B4 | Re-enable Accessibility and return to the app. | The event tap restarts and System Health returns to **Active**. | |
| B5 | If a rebuilt ad-hoc copy leaves a stale approval, remove the old Accessibility entry, quit the app, reopen the `/Applications` copy, and request permission again. | The current build can be approved and becomes **Active**. | |
| B6 | With permission granted, select **Retry** after any reproducible start failure. | The engine rechecks runtime state and either becomes **Active** or keeps an actionable failure status. | |

Never attach the contents of the macOS Transparency, Consent, and Control
database to a bug report.

## C. External-wheel and native-input behavior

Use a long document or webpage with enough content to make changes obvious.

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| C1 | Scroll with a discrete external wheel. | Movement is transformed into smooth pixel scrolling without duplicate input. | |
| C2 | Scroll with a trackpad or Magic Mouse. | Native continuous scrolling passes through unchanged. | |
| C3 | Compare **Feel**: Responsive, Balanced, and Glide. | Each preset changes responsiveness, acceleration, and direction-change behavior in the expected order. | |
| C4 | Compare **Speed**: Slow, Medium, and Fast. | Distance increases consistently from Slow to Fast. | |
| C5 | Compare **Smoothness**: Low, Medium, and High. | The scroll tail becomes progressively longer; no preset sticks or runs indefinitely. | |
| C6 | Set **Minimum wheel step** near its minimum, default, and maximum, then turn it off and on again. | Enabled input respects the configured minimum; when disabled, its controls remain visible but unavailable and input does not enforce it; the saved value returns unchanged when re-enabled. | |
| C7 | Enable **Reverse scrolling** and test the external mouse, then the native input. | External-wheel direction reverses; trackpad or Magic Mouse direction does not change. | |
| C8 | Enable **Adaptive precision**, pause, then move one notch and follow with rapid notches. | The first movement is precise and subsequent rapid movement ramps smoothly. | |
| C9 | Reverse wheel direction while momentum remains. | Existing momentum brakes immediately rather than sliding far in the old direction. | |
| C10 | Enable **Trackpad-like gestures** and test a compatible horizontal-navigation view. | Gesture phases begin, change, and end cleanly; navigation does not remain stuck. | |
| C11 | Test on each available 60 Hz and high-refresh-rate display. | Perceived distance remains comparable and animation stays display-synchronized. | |

## D. Modifier keys

Use the assignments shown in **Modifier Keys** and consult
[Modifier Key Behavior](MODIFIER_BEHAVIOR.md) for overlap rules.

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| D1 | Hold **Horizontal scrolling** and move a vertical-dominant wheel. | Vertical input becomes horizontal scrolling. | |
| D2 | Hold **Zoom** in an app that supports modifier-scroll zoom. | The selected modifier is forwarded and the app zooms; Mac Smooth Scroll does not implement its own zoom command. | |
| D3 | Hold **Faster scrolling**. | Movement is temporarily faster. | |
| D4 | Hold **Precision scrolling**. | Movement is temporarily smaller and more precise. | |
| D5 | Assign the same key to Precision and Faster. | Precision wins. | |
| D6 | Assign the same key to Horizontal and Precision. | Horizontal conversion and precision speed both apply. | |
| D7 | Assign the same key to Horizontal and Faster. | Horizontal conversion and faster speed both apply. | |
| D8 | Hold Zoom together with any active transform key. | The transform applies and Zoom is suppressed. | |
| D9 | Press or release a modifier during an existing wheel burst. | The current animated tail keeps the modifiers captured at the burst start. | |
| D10 | Assign **None** to an action. | That action no longer activates. | |

Record the foreground app used for D2 because modifier-scroll zoom support is
application-specific.

## E. Menu bar and background mode

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| E1 | Close Settings with the red close button. | Settings and the Dock icon disappear; the menu-bar item and scrolling remain active. | |
| E2 | Restore Settings, then press `Command-H`. | The app hides to the menu bar with no Dock icon. | |
| E3 | Restore Settings, then select **Hide to Menu Bar**. | The same background state is entered. | |
| E4 | Disable **Show in menu bar**, then hide the app. | The preference is enabled automatically before the Dock icon disappears. | |
| E5 | Select **Open Settings…** from the menu-bar menu. | The Dock icon and existing Settings window return without duplication. | |
| E6 | Select **Smooth Scrolling** in the menu. | The checkmark, header switch, engine status, and actual scrolling all reflect the new state. | |
| E7 | Change **Feel** and **Speed** from their menu submenus. | Checkmarks and Settings controls update immediately. | |
| E8 | Select **Quit Mac Smooth Scroll**. | The app, menu-bar item, event tap, and synthetic scrolling stop. | |

## F. Launch at Login

Run these cases with the app installed in `/Applications`.

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| F1 | Enable **Launch at login**. | System Health reports **Ready**, or shows **Approval required** with an Open Settings action. | |
| F2 | If requested, approve the item under **General → Login Items**. | Status changes to **Ready** without changing the saved preference. | |
| F3 | Log out and back in, or restart the Mac. | The helper launches the main app in background mode: scrolling and the menu-bar item are available with no Settings window or Dock icon. | |
| F4 | Open Mac Smooth Scroll manually after the background launch. | The existing app becomes visible and shows one Settings window. | |
| F5 | Replace the app with a newer build while Launch at Login remains enabled, then launch it once. | The registered helper refreshes to the installed build and remains usable. | |
| F6 | Disable **Launch at login**, quit, then repeat a login. | Mac Smooth Scroll does not launch automatically and System Health reports **Off**. | |
| F7 | If System Health reports **Registration missing**, select **Repair**. | The embedded helper is registered without changing the enabled preference. | |

## G. Competing mouse utilities and engine recovery

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| G1 | Start Mac Mouse Fix while Mac Smooth Scroll is active. | Mac Smooth Scroll pauses, reports **Driver conflict**, and avoids duplicate transformation. | |
| G2 | Select **Quit Mac Mouse Fix** from System Health. | A graceful quit is requested; Mac Smooth Scroll resumes when the conflict clears. | |
| G3 | If graceful termination is declined or fails, quit Mac Mouse Fix manually. | The warning remains actionable until the process exits, then the engine resumes. | |
| G4 | If the event tap is interrupted during testing, observe System Health. | **Recovering** returns to **Active** automatically, or changes to **Could not start** with **Retry**. | |
| G5 | Test alongside any other installed mouse utility. | Record whether scrolling is clear, doubled, distorted, or blocked; no automatic detection is expected for utilities other than Mac Mouse Fix. | |

Mark unavailable third-party utilities **Not run**, not **Pass**.

## H. Reset and uninstall preparation

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| H1 | Change scrolling presets, toggles, minimum step, and modifier assignments, then select **Reset Scrolling Settings…** and cancel. | No setting changes. | |
| H2 | Confirm **Reset Scrolling Settings…**. | Scrolling and modifier values return to documented defaults. | |
| H3 | Check **Show in menu bar**, **Launch at login**, setup completion, and the selected tab after reset. | App preferences remain unchanged. | |
| H4 | Disable Minimum wheel step, change its saved value, then select its **Reset** action. | Minimum wheel step turns on and returns to `18.00 pt`; unrelated settings remain unchanged. | |
| H5 | Prepare to uninstall by disabling **Launch at login**, then quit from the menu bar. | The helper is unregistered and no app process or menu-bar item remains. | |
| H6 | Review the README uninstall steps without attaching private system data. | The instructions cover app removal, Accessibility cleanup, and optional preference deletion. | |

## I. Basic interface accessibility

| ID | Test | Expected result | Result |
| --- | --- | --- | --- |
| I1 | Navigate tabs and controls with Full Keyboard Access. | Focus is visible and every control is reachable in a logical order. | |
| I2 | Inspect the header, tabs, health rows, step control, modifier pickers, and menu-bar item with VoiceOver. | Controls have understandable labels, values, and actions; status meaning is available without color alone. | |
| I3 | Check light and dark appearance at the minimum window size. | Text remains readable, controls do not overlap, and each tab scrolls when needed. | |

## Pull-request result template

Copy this compact report into the pull request. Add focused failure notes below
the table; do not paste private system logs.

```md
### Manual macOS regression

| Field | Result |
| --- | --- |
| Commit | `<full commit SHA>` |
| App | `<version> (<build>)` |
| macOS | `<version and build>` |
| Apple Silicon | `<M1/M2/M3/M4/later>` |
| Display | `<refresh rate>` |
| Mouse | `<model; notched/free-spinning>` |
| Native input | `<trackpad/Magic Mouse/not run>` |
| Other mouse utilities | `<none or names>` |

| Sections | Result |
| --- | --- |
| A. Installation and launch | Pass / Fail / Blocked / Not run |
| B. Accessibility | Pass / Fail / Blocked / Not run |
| C. Scrolling and native input | Pass / Fail / Blocked / Not run |
| D. Modifier keys | Pass / Fail / Blocked / Not run |
| E. Menu bar and background | Pass / Fail / Blocked / Not run |
| F. Launch at Login | Pass / Fail / Blocked / Not run |
| G. Conflicts and recovery | Pass / Fail / Blocked / Not run |
| H. Reset and uninstall preparation | Pass / Fail / Blocked / Not run |
| I. Interface accessibility | Pass / Fail / Blocked / Not run |

Failures or limitations:
- `<case ID — observed result and minimal reproduction steps>`
```

For a failure, include the case ID, expected result, observed result, frequency,
and the smallest reliable reproduction. Use **Copy Diagnostics** for the
privacy-safe app status fields.
