#!/bin/bash
# Builds DockSheath.app from the Swift Package Manager build output.
# Usage: Scripts/build_app.sh [debug|release] [output-directory] [codesign-identity]
#
# codesign-identity is optional. If omitted, the assembled .app is left as-is
# (just the ad-hoc signature the linker applies to the raw Mach-O binary), the
# same as before this parameter existed. Pass a codesign identity (e.g. the
# common name of a local self-signed certificate) to have this script sign the
# whole bundle with it instead, which keeps macOS's TCC permission grants
# (Accessibility, Screen Recording) stable across rebuilds — see Scripts/update.sh.
set -euo pipefail

CONFIGURATION="${1:-release}"
OUTPUT_DIR="${2:-build}"
CODESIGN_IDENTITY="${3:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockSheath"
APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"

cd "$ROOT_DIR"

echo "==> Building ${APP_NAME} (${CONFIGURATION})"
swift build -c "$CONFIGURATION"

BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Sources/${APP_NAME}/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# SwiftPM copies target resources into a `<Package>_<Target>.bundle` next to
# the built executable. Copy it into Contents/Resources so Bundle.module can
# find it via Bundle.main.resourceURL at runtime inside a real .app bundle.
for bundle in "$BIN_PATH"/*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
done

if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "==> Signing ${APP_BUNDLE} with identity \"${CODESIGN_IDENTITY}\""
  codesign --force --sign "$CODESIGN_IDENTITY" \
    --entitlements "$ROOT_DIR/Sources/${APP_NAME}/App/${APP_NAME}.entitlements" \
    "$APP_BUNDLE"
fi

echo "==> Built $APP_BUNDLE"
