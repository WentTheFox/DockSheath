#!/bin/bash
# Pulls the latest source, rebuilds DockSheath.app, replaces the installed
# copy, clears the quarantine attribute on the freshly built (ad-hoc signed,
# unnotarized) app so Gatekeeper doesn't block it, and resets its stale
# Accessibility/Screen Recording TCC grants so you get a clean permission
# prompt on next launch instead of having to remove and re-add it by hand.
# Usage: Scripts/update.sh [install-directory]  (defaults to /Applications)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockSheath"
INSTALL_DIR="${1:-/Applications}"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"

cd "$ROOT_DIR"

echo "==> Pulling latest changes"
git pull

echo "==> Building ${APP_NAME} (release)"
Scripts/build_app.sh release build

if pgrep -x "$APP_NAME" > /dev/null; then
  echo "==> Quitting running ${APP_NAME} (rebuilt binary has a new ad-hoc signature, so it needs a relaunch anyway)"
  killall "$APP_NAME" || true
  sleep 1
fi

echo "==> Replacing ${INSTALLED_APP}"
rm -rf "$INSTALLED_APP"
mv "build/${APP_NAME}.app" "$INSTALLED_APP"

echo "==> Clearing quarantine attribute (Gatekeeper bypass)"
xattr -cr "$INSTALLED_APP"

# Every rebuild gets a fresh ad-hoc signature, which TCC (macOS's permission
# database) treats as a different app from the one that was actually
# granted access — the existing Accessibility/Screen Recording entries go
# stale and stop working, but don't disappear on their own, which is why
# they otherwise need to be removed and re-added by hand in System Settings
# after every build. Resetting them here means the next launch just prompts
# fresh instead.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "Sources/${APP_NAME}/App/Info.plist")"
echo "==> Resetting stale Accessibility/Screen Recording grants for ${BUNDLE_ID}"
tccutil reset Accessibility "$BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" || true

echo "==> Updated. Launch it with: open \"$INSTALLED_APP\" (you'll need to re-grant Accessibility access)"
