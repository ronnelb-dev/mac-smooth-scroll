# Installing Mac Smooth Scroll

Mac Smooth Scroll 0.3.1 Preview requires an Apple Silicon Mac running macOS 13
or later.

> **Preview build:** This download is not Developer ID signed or notarized.
> macOS may require an extra confirmation before opening it. Do not install a
> copy downloaded from anywhere other than this repository's GitHub release.

## Install from the DMG

1. Download the DMG, `.sha256` checksum, and `.json` release manifest from the
   same GitHub preview release.
2. Verify the download as described below.
3. Open `Mac-Smooth-Scroll-0.3.1-arm64.dmg`.
4. Follow the arrow and drag **Mac Smooth Scroll** onto the **Applications**
   shortcut.
5. Eject the Mac Smooth Scroll disk image.
6. Open `/Applications/Mac Smooth Scroll.app`.

If macOS says it cannot verify the developer:

1. Open **System Settings → Privacy & Security**.
2. Scroll to the security message about Mac Smooth Scroll.
3. Select **Open Anyway**, then confirm **Open**.

## Allow Accessibility access

Mac Smooth Scroll cannot transform external mouse-wheel events until
Accessibility access is enabled.

1. In Mac Smooth Scroll, select **Request Permission**.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable **Mac Smooth Scroll**.
4. If it is missing, select `+` and choose
   `/Applications/Mac Smooth Scroll.app`.
5. Quit and reopen Mac Smooth Scroll if its status does not update.

If an older entry remains after replacing the app, remove that entry, add the
copy from `/Applications` again, and relaunch.

## Verify the download

From the folder containing both downloaded files, run:

```sh
shasum -a 256 -c Mac-Smooth-Scroll-0.3.1-arm64.dmg.sha256
```

The command should report `OK`.

The release manifest records the exact version, build, Apple Silicon
architecture, minimum macOS version, bundle identifiers, signature type,
notarization state, artifact name, and checksum. It does not replace checksum
verification.

## Update or uninstall

To update, quit Mac Smooth Scroll and drag the newer app onto Applications,
then select **Replace**.

To uninstall:

1. Disable **Launch at login** inside the app.
2. Quit Mac Smooth Scroll.
3. Move `/Applications/Mac Smooth Scroll.app` to the Trash.
4. Remove its entry from Accessibility settings.
