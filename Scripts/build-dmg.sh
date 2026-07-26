#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_name="Mac Smooth Scroll"
app_path="$project_dir/dist/$app_name.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/Resources/Info.plist")"
dmg_name="Mac-Smooth-Scroll-$version-arm64.dmg"
dmg_path="$project_dir/dist/$dmg_name"
checksum_path="$dmg_path.sha256"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/mac-smooth-scroll-dmg.XXXXXX")"

cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT

"$project_dir/Scripts/build-app.sh" "$configuration"
codesign --verify --deep --strict --verbose=2 "$app_path"

ditto "$app_path" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
    -volname "$app_name $version" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    "$dmg_path"

hdiutil verify "$dmg_path"

(
    cd "$project_dir/dist"
    shasum -a 256 "$dmg_name" > "$dmg_name.sha256"
)

echo "$dmg_path"
echo "$checksum_path"
