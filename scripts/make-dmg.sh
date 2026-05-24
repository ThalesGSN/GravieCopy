#!/usr/bin/env bash
# Creates a drag-to-install DMG for GravieCopy.
# Usage: ./scripts/make-dmg.sh [version]
#   version  defaults to the latest git tag (e.g. v1.0.0)
set -euo pipefail

APP="GravieCopy"
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
STAGING="$REPO_DIR/build/dmg-staging"
OUTPUT="$REPO_DIR/build/${APP}-${VERSION}.dmg"

echo "→ Building ${APP} ${VERSION} (Release)"
xcodebuild \
  -workspace "$REPO_DIR/${APP}.xcworkspace" \
  -scheme "$APP" \
  -configuration Release \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" \
             | grep -v "rsync\|Sandbox\|SQLCipher"

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/${APP}-*/Build/Products/Release \
  -name "${APP}.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "✗ Could not find built ${APP}.app" >&2; exit 1
fi
echo "→ Found: $APP_PATH"

echo "→ Staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

mkdir -p "$REPO_DIR/build"
rm -f "$OUTPUT"

echo "→ Creating DMG"
create-dmg \
  --volname "$APP" \
  --background "$SCRIPT_DIR/dmg-background.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 120 \
  --icon "${APP}.app" 165 185 \
  --hide-extension "${APP}.app" \
  --app-drop-link 495 185 \
  "$OUTPUT" \
  "$STAGING/"

echo "✓ Done: $OUTPUT ($(du -sh "$OUTPUT" | cut -f1))"
