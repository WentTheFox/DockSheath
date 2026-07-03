#!/bin/bash
# Pulls the latest source, rebuilds DockSheath.app, replaces the installed
# copy, and clears the quarantine attribute on the freshly built (ad-hoc
# signed, unnotarized) app so Gatekeeper doesn't block it.
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

echo "==> Updated. Launch it with: open \"$INSTALLED_APP\""
