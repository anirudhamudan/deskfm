#!/bin/zsh
# Builds Spotbar.app. Pass --install to copy it into /Applications and launch it.
set -euo pipefail
cd "${0:A:h}"

swift build -c release
APP=build/Spotbar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Spotbar "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Spotbar || true
  while pgrep -x Spotbar >/dev/null; do sleep 0.2; done
  rm -rf /Applications/Spotbar.app
  cp -R "$APP" /Applications/
  open /Applications/Spotbar.app --args --enable-login-item
  echo "Installed to /Applications, launched, and set to launch at login"
fi
