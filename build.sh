#!/bin/zsh
# Builds "Desk FM.app" (Apple Silicon + Intel) into build/.
#   ./build.sh            build only
#   ./build.sh --install  also copy to /Applications, launch, and turn on launch at login
#   ./build.sh --release  also zip it for a GitHub release (build/DeskFM-<version>.zip)
set -euo pipefail
cd "${0:A:h}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

# Keep Swift's build cache out of the project: if the folder syncs to iCloud
# (e.g. on the Desktop), syncing the cache corrupts its database mid-build.
CACHE="$HOME/Library/Caches/DeskFM-build"
SWIFT_BUILD=(swift build -c release --arch arm64 --arch x86_64 --scratch-path "$CACHE")
"${SWIFT_BUILD[@]}"
BIN=$("${SWIFT_BUILD[@]}" --show-bin-path)/DeskFM

# App icon, drawn from the same lamp as the menu bar icon.
ICONWORK="$CACHE/icon"
mkdir -p "$ICONWORK"
swiftc -O Sources/DeskFM/LampGlyph.swift scripts/make-icon/main.swift -o "$ICONWORK/make-icon"
rm -rf "$ICONWORK/AppIcon.iconset"
"$ICONWORK/make-icon" "$ICONWORK/AppIcon.iconset"

APP="build/Desk FM.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
iconutil -c icns "$ICONWORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/DeskFM"))"

case "${1:-}" in
  --install)
    pkill -x DeskFM || true
    while pgrep -x DeskFM >/dev/null; do sleep 0.2; done
    rm -rf "/Applications/Desk FM.app"
    cp -R "$APP" /Applications/
    open "/Applications/Desk FM.app" --args --enable-login-item
    echo "Installed to /Applications, launched, and set to launch at login"
    ;;
  --release)
    ZIP="build/DeskFM-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Release zip: $ZIP ($(du -h "$ZIP" | cut -f1))"
    ;;
esac
