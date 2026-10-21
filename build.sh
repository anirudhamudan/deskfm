#!/bin/zsh
# Builds Spotbar.app (Apple Silicon + Intel) into build/.
#   ./build.sh            build only
#   ./build.sh --install  also copy to /Applications, launch, and turn on launch at login
#   ./build.sh --release  also zip it for a GitHub release (build/Spotbar-<version>.zip)
set -euo pipefail
cd "${0:A:h}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Spotbar

# App icon, drawn from the same pin as the menu bar icon.
ICONWORK=.build/icon
mkdir -p "$ICONWORK"
swiftc -O Sources/Spotbar/PinGlyph.swift scripts/make-icon/main.swift -o "$ICONWORK/make-icon"
rm -rf "$ICONWORK/AppIcon.iconset"
"$ICONWORK/make-icon" "$ICONWORK/AppIcon.iconset"

APP=build/Spotbar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
iconutil -c icns "$ICONWORK/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/Spotbar"))"

case "${1:-}" in
  --install)
    pkill -x Spotbar || true
    while pgrep -x Spotbar >/dev/null; do sleep 0.2; done
    rm -rf /Applications/Spotbar.app
    cp -R "$APP" /Applications/
    open /Applications/Spotbar.app --args --enable-login-item
    echo "Installed to /Applications, launched, and set to launch at login"
    ;;
  --release)
    ZIP="build/Spotbar-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Release zip: $ZIP ($(du -h "$ZIP" | cut -f1))"
    ;;
esac
