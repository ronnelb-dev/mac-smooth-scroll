#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_name="Mac Smooth Scroll"
app_path="$project_dir/dist/$app_name.app"
info_plist="$project_dir/Resources/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist")"
minimum_macos="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info_plist")"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")"
launcher_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$project_dir/Resources/Launcher-Info.plist")"
dmg_name="Mac-Smooth-Scroll-$version-arm64.dmg"
dmg_path="$project_dir/dist/$dmg_name"
checksum_path="$dmg_path.sha256"
manifest_path="$project_dir/dist/Mac-Smooth-Scroll-$version-arm64-manifest.json"
volume_name="$app_name $version"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mac-smooth-scroll-dmg.XXXXXX")"
staging_dir="$work_dir/staging"
read_write_dmg="$work_dir/installer-rw.dmg"
background_path="$staging_dir/.background/background.png"
device=""

cleanup() {
    if [[ -n "$device" ]]; then
        hdiutil detach "$device" -quiet 2>/dev/null || true
    fi
    rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$staging_dir/.background"

"$project_dir/Scripts/build-app.sh" "$configuration"
codesign --verify --deep --strict --verbose=2 "$app_path"

ditto "$app_path" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"

swift "$project_dir/Scripts/render-dmg-background.swift" \
    "$background_path" \
    "$project_dir/Resources/Brand/MacSmoothScrollIcon.png" \
    "$version"

hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -format UDRW \
    -ov \
    "$read_write_dmg" >/dev/null

attach_output="$(
    hdiutil attach "$read_write_dmg" \
        -readwrite \
        -noverify \
        -noautoopen
)"
device="$(print -r -- "$attach_output" | awk '/^\/dev\// { print $1; exit }')"
mount_point="$(
    print -r -- "$attach_output" |
    awk -F '\t' '$NF ~ /^\/Volumes\// { print $NF; exit }'
)"
[[ -n "$device" && -d "$mount_point" ]] || {
    echo "Could not identify the writable DMG mount." >&2
    exit 1
}
mounted_volume_name="${mount_point:t}"

osascript - "$mounted_volume_name" "$app_name.app" "$mount_point" <<'APPLESCRIPT'
on run arguments
    set volumeName to item 1 of arguments
    set applicationName to item 2 of arguments
    set mountPath to item 3 of arguments
    set backgroundPicture to POSIX file (mountPath & "/.background/background.png") as alias

    tell application "Finder"
        delay 1
        tell disk volumeName
            open
            tell container window
                set current view to icon view
                set toolbar visible to false
                set statusbar visible to false
                set bounds to {100, 100, 760, 560}
            end tell

            tell icon view options of container window
                set arrangement to not arranged
                set icon size to 112
                set text size to 13
                set shows item info to false
                set shows icon preview to true
                set background picture to backgroundPicture
            end tell

            set position of item applicationName to {170, 220}
            set position of item "Applications" to {490, 220}
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
APPLESCRIPT

sync
hdiutil detach "$device" -quiet
device=""

rm -f "$dmg_path" "$checksum_path" "$manifest_path"
hdiutil convert \
    "$read_write_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$dmg_path" >/dev/null

hdiutil verify "$dmg_path"

checksum="$(shasum -a 256 "$dmg_path" | awk '{ print $1 }')"
print -r -- "$checksum  $dmg_name" > "$checksum_path"

signature_type="certificate"
signature_details="$(codesign -dvv "$app_path" 2>&1)"
if grep -q '^Signature=adhoc$' <<<"$signature_details"; then
    signature_type="ad-hoc"
fi

cat > "$manifest_path" <<EOF
{
  "schemaVersion": 1,
  "appName": "$app_name",
  "version": "$version",
  "build": "$build",
  "architecture": "arm64",
  "minimumMacOS": "$minimum_macos",
  "bundleIdentifier": "$bundle_identifier",
  "launcherBundleIdentifier": "$launcher_identifier",
  "artifact": "$dmg_name",
  "sha256": "$checksum",
  "signatureType": "$signature_type",
  "notarization": "not-submitted-by-build"
}
EOF

python3 -m json.tool "$manifest_path" >/dev/null

echo "$dmg_path"
echo "$checksum_path"
echo "$manifest_path"
