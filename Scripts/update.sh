#!/bin/bash
# Pulls the latest source, rebuilds DockSheath.app, replaces the installed
# copy, and clears the quarantine attribute on the freshly built app so
# Gatekeeper doesn't block it.
#
# TCC (macOS's permission database) ties the Accessibility/Screen Recording
# grants to the app's code signature. A plain ad-hoc signature is derived
# from the binary's own contents, so it changes on every rebuild and TCC
# treats each rebuilt binary as a different, ungranted app. To avoid having
# to remove and re-add DockSheath in System Settings after every single
# rebuild, this script instead signs the app with a stable local self-signed
# certificate (identity name in $CODESIGN_IDENTITY_NAME below) — same identity
# every build, so the grant carries over. See the "Permissions" section of
# README.md for how to create that certificate once.
#
# Usage: Scripts/update.sh [install-directory]  (defaults to /Applications)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockSheath"
INSTALL_DIR="${1:-/Applications}"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"
CODESIGN_IDENTITY_NAME="${DOCKSHEATH_CODESIGN_IDENTITY:-DockSheath Local Signing}"

cd "$ROOT_DIR"

echo "==> Pulling latest changes"
git pull

echo "==> Checking for local code-signing certificate (\"${CODESIGN_IDENTITY_NAME}\")"
while ! security find-identity -v -p codesigning | grep -q "$CODESIGN_IDENTITY_NAME"; do
  cat <<EOF

No code-signing certificate named "${CODESIGN_IDENTITY_NAME}" was found in
your login keychain. Without one, every rebuild gets a fresh ad-hoc
signature and you'll have to re-grant Accessibility access from scratch
each time.

To fix this once, create a free local certificate:
  1. Open Keychain Access (Applications > Utilities > Keychain Access)
  2. Menu bar: Keychain Access > Certificate Assistant > Create a Certificate...
  3. Name: ${CODESIGN_IDENTITY_NAME}
     Identity Type: Self Signed Root
     Certificate Type: Code Signing
  4. Click Create, then Done

(To use a different certificate name, set DOCKSHEATH_CODESIGN_IDENTITY before
running this script.)

EOF
  read -n 1 -s -r -p "Press any key once the certificate is installed to continue (Ctrl+C to abort)... "
  echo
done
echo "==> Found certificate"

echo "==> Building ${APP_NAME} (release)"
Scripts/build_app.sh release build "$CODESIGN_IDENTITY_NAME"

if pgrep -x "$APP_NAME" > /dev/null; then
  echo "==> Quitting running ${APP_NAME} for the rebuilt binary to replace it"
  killall "$APP_NAME" || true
  sleep 1
fi

echo "==> Replacing ${INSTALLED_APP}"
rm -rf "$INSTALLED_APP"
mv "build/${APP_NAME}.app" "$INSTALLED_APP"

echo "==> Clearing quarantine attribute (Gatekeeper bypass)"
xattr -cr "$INSTALLED_APP"

echo "==> Updated. Launch it with: open \"$INSTALLED_APP\""
