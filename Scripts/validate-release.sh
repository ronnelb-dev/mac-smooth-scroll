#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
allow_adhoc=false

if [[ "${1:-}" == "--allow-adhoc" ]]; then
    allow_adhoc=true
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--allow-adhoc]" >&2
    exit 64
fi

info_plist="$project_dir/Resources/Info.plist"
launcher_info_plist="$project_dir/Resources/Launcher-Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
minimum_macos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info_plist")"
app="$project_dir/dist/Mac Smooth Scroll.app"
launcher="$app/Contents/Library/LoginItems/Mac Smooth Scroll Launcher.app"
dmg_name="Mac-Smooth-Scroll-$version-arm64.dmg"
dmg="$project_dir/dist/$dmg_name"
checksum="$dmg.sha256"
manifest="$project_dir/dist/Mac-Smooth-Scroll-$version-arm64-manifest.json"
mount_point="$(mktemp -d "${TMPDIR:-/tmp}/mac-smooth-scroll-validate.XXXXXX")"
device=""

cleanup() {
    if [[ -n "$device" ]]; then
        hdiutil detach "$device" -quiet 2>/dev/null || true
    fi
    rmdir "$mount_point" 2>/dev/null || true
}
trap cleanup EXIT

fail() {
    echo "Release validation failed: $1" >&2
    exit 1
}

[[ "$(uname -m)" == "arm64" ]] || fail "validation must run on Apple Silicon"
[[ -d "$app" ]] || fail "missing built application"
[[ -d "$launcher" ]] || fail "missing embedded login helper"
[[ -f "$dmg" ]] || fail "missing versioned DMG"
[[ -f "$checksum" ]] || fail "missing checksum"
[[ -f "$manifest" ]] || fail "missing release manifest"

main_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
launcher_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$launcher/Contents/Info.plist")"
main_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
launcher_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$launcher/Contents/Info.plist")"

[[ "$main_version" == "$version" && "$launcher_version" == "$version" ]] ||
    fail "main and helper versions must match source version $version"
[[ "$main_build" == "$build" && "$launcher_build" == "$build" ]] ||
    fail "main and helper builds must match source build $build"
[[ "$(lipo -archs "$app/Contents/MacOS/MacSmoothScroll")" == "arm64" ]] ||
    fail "main executable is not arm64-only"
[[ "$(lipo -archs "$launcher/Contents/MacOS/MacSmoothScrollLauncher")" == "arm64" ]] ||
    fail "login helper is not arm64-only"

codesign --verify --strict --verbose=2 "$launcher"
codesign --verify --deep --strict --verbose=2 "$app"

signature="$(codesign -dvv "$app" 2>&1)"
expected_signature_type="certificate"
if grep -q '^Signature=adhoc$' <<<"$signature"; then
    expected_signature_type="ad-hoc"
fi
if [[ "$expected_signature_type" == "ad-hoc" && "$allow_adhoc" != true ]]; then
    fail "app is ad-hoc signed; pass --allow-adhoc only for preview validation"
fi

hdiutil verify "$dmg"
(
    cd "$project_dir/dist"
    shasum -a 256 -c "$(basename "$checksum")"
)

device="$(
    hdiutil attach "$dmg" \
        -nobrowse \
        -readonly \
        -mountpoint "$mount_point" |
    awk '/^\/dev\// { print $1; exit }'
)"

[[ -d "$mount_point/Mac Smooth Scroll.app" ]] || fail "DMG app is missing"
[[ -L "$mount_point/Applications" ]] || fail "Applications shortcut is missing"
[[ "$(readlink "$mount_point/Applications")" == "/Applications" ]] ||
    fail "Applications shortcut has the wrong destination"
[[ -f "$mount_point/.background/background.png" ]] || fail "DMG background is missing"
[[ -f "$mount_point/.DS_Store" ]] || fail "DMG Finder layout is missing"

background_width="$(sips -g pixelWidth "$mount_point/.background/background.png" | awk '/pixelWidth/ { print $2 }')"
background_height="$(sips -g pixelHeight "$mount_point/.background/background.png" | awk '/pixelHeight/ { print $2 }')"
[[ "$background_width" == "660" && "$background_height" == "430" ]] ||
    fail "DMG background must be 660x430"

codesign --verify --deep --strict --verbose=2 "$mount_point/Mac Smooth Scroll.app"

manifest_value() {
    python3 - "$manifest" "$1" <<'PYTHON'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    value = json.load(manifest_file)[sys.argv[2]]
print(value)
PYTHON
}

expected_checksum="$(awk '{ print $1 }' "$checksum")"
[[ "$(manifest_value version)" == "$version" ]] || fail "manifest version mismatch"
[[ "$(manifest_value build)" == "$build" ]] || fail "manifest build mismatch"
[[ "$(manifest_value architecture)" == "arm64" ]] || fail "manifest architecture mismatch"
[[ "$(manifest_value minimumMacOS)" == "$minimum_macos" ]] || fail "manifest macOS mismatch"
[[ "$(manifest_value artifact)" == "$dmg_name" ]] || fail "manifest artifact mismatch"
[[ "$(manifest_value sha256)" == "$expected_checksum" ]] || fail "manifest checksum mismatch"
[[ "$(manifest_value signatureType)" == "$expected_signature_type" ]] ||
    fail "manifest signature type mismatch"
[[ "$(manifest_value bundleIdentifier)" ==
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")" ]] ||
    fail "manifest app identifier mismatch"
[[ "$(manifest_value launcherBundleIdentifier)" ==
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$launcher_info_plist")" ]] ||
    fail "manifest helper identifier mismatch"

echo "Release validation passed:"
echo "  Mac Smooth Scroll $version ($build)"
echo "  Apple Silicon arm64 • macOS $minimum_macos+"
echo "  $dmg_name"
echo "  Signature: $(manifest_value signatureType)"
echo "  Notarization: $(manifest_value notarization)"
