#!/bin/bash

set -euo pipefail

APP_NAME="QuietReader"
VERSION="1.0.0"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$ROOT_DIR/build.sh"
rm -rf "$ROOT_DIR/build/dmg-root"
mkdir -p "$ROOT_DIR/build/dmg-root"
cp -R "$ROOT_DIR/build/MenuReader.app" "$ROOT_DIR/build/dmg-root/$APP_NAME.app"
ln -s /Applications "$ROOT_DIR/build/dmg-root/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$ROOT_DIR/build/dmg-root" \
  -ov \
  -format UDZO \
  "$ROOT_DIR/build/$APP_NAME-$VERSION.dmg"

echo "生成完成：build/$APP_NAME-$VERSION.dmg"
