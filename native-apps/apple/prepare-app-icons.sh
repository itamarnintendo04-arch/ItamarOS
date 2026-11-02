#!/usr/bin/env bash
# Prepare native AppIcon raster assets before XcodeGen/Xcode builds.
# This script does not sign or distribute any application.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_ICON="$ROOT/native-apps/apple/iOS/Assets.xcassets/AppIcon.appiconset/Icon.png"
CLIMB_ICON="$ROOT/native-apps/apple/CloudClimb/Assets.xcassets/CloudClimbAppIcon.appiconset/Icon.png"
SOURCE="$ROOT/assets/branding/cloud-climb-icon.svg"

if ! command -v rsvg-convert >/dev/null; then
  echo "Missing rsvg-convert. On macOS: brew install librsvg" >&2
  exit 1
fi
test -s "$IOS_ICON"
test -s "$SOURCE"
mkdir -p "$(dirname "$CLIMB_ICON")"
rsvg-convert --format=png --width=1024 --height=1024 "$SOURCE" > "$CLIMB_ICON"

for icon in "$IOS_ICON" "$CLIMB_ICON"; do
  test -s "$icon"
  /usr/bin/sips -g pixelWidth -g pixelHeight "$icon" | grep -q 'pixelWidth: 1024'
  /usr/bin/sips -g pixelWidth -g pixelHeight "$icon" | grep -q 'pixelHeight: 1024'
  # PNG signature / real image rather than an empty icon asset.
  /usr/bin/file "$icon" | grep -q 'PNG image data'
done
echo "Verified both ItamarOS and Cloud Climb iOS 1024x1024 AppIcon assets"
