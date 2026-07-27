# Troubleshooting Mac Smooth Scroll

## Accessibility is enabled but the app still asks for permission

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Switch Mac Smooth Scroll off, then on again.
3. Return to the app and wait a few seconds for its status to refresh.
4. If the warning remains, remove the existing Mac Smooth Scroll entry from
   Accessibility.
5. Quit Mac Smooth Scroll completely.
6. Confirm that the copy you intend to run is in `/Applications`.
7. Reopen that copy and select **Request Permission** again.

The Accessibility row under **System Health** remains visible after permission
is granted and changes to **Ready**.

Ad-hoc signatures change when the app is rebuilt. macOS may treat a rebuilt or
moved app as a different application, even when its name and bundle identifier
are unchanged. Remove the stale Accessibility entry and approve the current
build.

## The status says "Could not start"

- Confirm Accessibility is enabled for the exact app copy that is running.
- Quit and reopen Mac Smooth Scroll after changing permission.
- Make sure another copy of the app is not running from `dist`, Downloads, or
  another folder.
- Quit other mouse-driver utilities temporarily.
- If the event tap still cannot start, restart the Mac and try again.

Use **Retry** on the Scroll engine row after correcting the permission or
driver problem.

Input Monitoring is not normally required by Mac Smooth Scroll's permission
check. Accessibility is the primary permission for its modifying event tap.

## Mac Mouse Fix is running

Mac Smooth Scroll pauses automatically while the Mac Mouse Fix app or helper is
running. Select **Quit Mac Mouse Fix** on the Mouse drivers health row to
request a normal quit, or quit Mac Mouse Fix from its own menu. Mac Smooth
Scroll should resume automatically. The app never force-quits another driver.

Other mouse utilities are not detected automatically. If scrolling is doubled,
distorted, or unusually fast, quit Logitech Options, SteerMouse, LinearMouse,
or other software that transforms wheel events and test again.

## Smooth scrolling is off

Turn on the switch in the settings header or select the checkmarked
**Smooth Scrolling** item in the menu-bar menu.

The first line of the menu reports the live scroll-engine status. When
scrolling needs attention, use the contextual command shown below the Feel and
Speed submenus to open Accessibility Settings, retry the engine, or quit Mac
Mouse Fix.

## The settings window and Dock icon disappeared

This is expected after closing the window, pressing `⌘H`, or choosing
**Hide to Menu Bar**. Select the mouse icon in the menu bar and choose
**Open Settings…**.

You can also reopen Mac Smooth Scroll from `/Applications`. The existing
settings window is restored instead of creating another one.

## The menu-bar icon is missing

Open Mac Smooth Scroll from `/Applications`, then enable
**Show in menu bar** under **App**.

Choosing **Hide to Menu Bar** automatically enables the menu-bar item before
the Dock icon disappears.

## Launch at Login does not work

1. Keep Mac Smooth Scroll installed in `/Applications`.
2. Enable **Launch at login** in the app.
3. If approval is requested, open
   **System Settings → General → Login Items**.
4. Allow Mac Smooth Scroll and try the login launch again.

Check the **Launch at login** row under **System Health**. If registration is
missing, select **Repair**. If approval is required, select **Open Settings**
and allow the app there.

The embedded helper starts the main app in background mode. It should show a
menu-bar item without opening Settings or adding a Dock icon.

Disable **Launch at login** before moving, replacing, or uninstalling the app.

## Trackpad or Magic Mouse behavior

Mac Smooth Scroll transforms discrete external mouse-wheel events. Continuous
events from a trackpad or Magic Mouse are passed through unchanged.

## Collecting useful information for a bug report

Select **Copy Diagnostics** under **System Health** and include the result.
It contains only app, macOS, architecture, and health-state information.

Include:

- Mac Smooth Scroll version or Git commit
- macOS version
- Apple Silicon Mac model
- Mouse model
- Relevant settings and modifier assignments
- Accessibility status
- Other running mouse utilities
- Exact reproduction steps

Remove email addresses, certificates, private keys, passwords, and other
personal information before attaching screenshots or logs.
