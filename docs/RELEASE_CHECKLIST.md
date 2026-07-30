# Preview Release Checklist

Mac Smooth Scroll currently ships only as an Apple Silicon preview. The app
does not yet have a personal Developer ID Application signature or Apple
notarization, so every GitHub release must remain marked **Pre-release**.

## 1. Prepare the source

- Confirm `main` contains only the changes intended for the release.
- Update `CFBundleShortVersionString` and `CFBundleVersion` in both
  `Resources/Info.plist` and `Resources/Launcher-Info.plist`.
- Confirm the main app and login helper versions and builds match.
- Update README, installation, privacy, and troubleshooting documentation when
  behavior changes.
- Run:

  ```sh
  swift test --arch arm64
  git diff --check
  ```

## 2. Build and validate the preview

Build the complete release bundle:

```sh
./Scripts/build-dmg.sh
./Scripts/validate-release.sh --allow-adhoc
```

The `--allow-adhoc` flag is deliberate. Do not use it to describe an artifact
as production-signed or notarized.

Inspect the mounted DMG manually:

- The content is 660 × 430 points with no Finder toolbar or status bar.
- The branded background and three-step instruction are readable.
- Mac Smooth Scroll and Applications are large, separated, and aligned with
  the arrow.
- Dragging the app to Applications works.
- The app launches from Applications on an Apple Silicon Mac.
- Accessibility recovery and Launch at Login work after replacement.

Run the relevant sections of the
[manual macOS regression checklist](MANUAL_REGRESSION_CHECKLIST.md) and retain
the compact result with the release pull request. A passing build does not
replace physical mouse, permission, menu-bar, or login-session testing.

The build produces three files in `dist/`:

- `Mac-Smooth-Scroll-<version>-arm64.dmg`
- `Mac-Smooth-Scroll-<version>-arm64.dmg.sha256`
- `Mac-Smooth-Scroll-<version>-arm64-manifest.json`

## 3. Prepare the GitHub release

- Wait for the protected **Apple Silicon arm64 build** check on `main`.
- Create an annotated tag using a preview suffix, such as
  `v0.4.0-preview.1`.
- Create a GitHub release from that exact tag.
- Keep **Set as a pre-release** enabled.
- Use GitHub's generated release notes, then add:
  - A short user-facing summary
  - Apple Silicon and macOS 13 requirements
  - The ad-hoc signing and no-notarization warning
  - A link to `docs/INSTALLATION.md`
- Upload the DMG, checksum, and manifest together.
- Never upload `.app` directly or omit the checksum and manifest.

## 4. Verify after publishing

- Download all three assets from GitHub rather than reusing local files.
- Run:

  ```sh
  shasum -a 256 -c Mac-Smooth-Scroll-<version>-arm64.dmg.sha256
  ```

- Open the downloaded DMG and repeat the drag-to-Applications flow.
- Confirm the release is visibly labeled **Pre-release**.
- Confirm the release notes do not claim Developer ID signing, notarization,
  Gatekeeper approval, or production readiness.

## Stable-release gate

Do not publish a stable release until all of the following are available:

- A personal Apple Developer Program membership
- A Developer ID Application certificate and private key
- Hardened-runtime signing for the main app and nested helper
- Successful Apple notarization and stapling
- Gatekeeper verification on a separate Mac
