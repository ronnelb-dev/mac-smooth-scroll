#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-release}"
app_name="Mac Smooth Scroll"
bundle_dir="$project_dir/dist/$app_name.app"
contents_dir="$bundle_dir/Contents"
launcher_name="Mac Smooth Scroll Launcher"
launcher_bundle_dir="$contents_dir/Library/LoginItems/$launcher_name.app"
launcher_contents_dir="$launcher_bundle_dir/Contents"
iconset_dir="$project_dir/.build/AppIcon.iconset"
brand_icon="$project_dir/Resources/Brand/MacSmoothScrollIcon.png"

cd "$project_dir"

swift build -c "$configuration" --arch arm64

if [[ -e "$bundle_dir" ]]; then
    rm -rf "$bundle_dir"
fi
mkdir -p \
    "$contents_dir/MacOS" \
    "$contents_dir/Resources" \
    "$launcher_contents_dir/MacOS" \
    "$iconset_dir"

cp ".build/arm64-apple-macosx/$configuration/MacSmoothScroll" "$contents_dir/MacOS/MacSmoothScroll"
cp ".build/arm64-apple-macosx/$configuration/MacSmoothScrollLauncher" "$launcher_contents_dir/MacOS/MacSmoothScrollLauncher"
cp "Resources/Info.plist" "$contents_dir/Info.plist"
cp "Resources/Launcher-Info.plist" "$launcher_contents_dir/Info.plist"
cp "$brand_icon" "$contents_dir/Resources/BrandIcon.png"

sips -z 16 16 "$brand_icon" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$brand_icon" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$brand_icon" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$brand_icon" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$brand_icon" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$brand_icon" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$brand_icon" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$brand_icon" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$brand_icon" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$brand_icon" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_dir" -o "$contents_dir/Resources/AppIcon.icns"

signing_identity="${MAC_SMOOTH_SCROLL_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    signing_identity="$(
        security find-identity -v -p codesigning |
            awk '/Apple Development:/ && identity == "" { identity = $2 } END { print identity }'
    )"
fi

if [[ -n "$signing_identity" ]]; then
    codesign \
        --force \
        --options runtime \
        --timestamp=none \
        --sign "$signing_identity" \
        "$launcher_bundle_dir"
    codesign \
        --force \
        --options runtime \
        --timestamp=none \
        --sign "$signing_identity" \
        "$bundle_dir"
    echo "Signed with: $signing_identity"
else
    codesign --force --sign - "$launcher_bundle_dir"
    codesign --force --sign - "$bundle_dir"
    echo "Signed ad-hoc (no Apple Development identity was found)."
fi

echo "$bundle_dir"
