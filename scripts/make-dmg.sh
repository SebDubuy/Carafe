#!/bin/zsh
# Fabrique dist/Carafe.dmg (version Release, signée localement) à partir du projet.
# Utilisation, depuis la racine du projet :  ./scripts/make-dmg.sh
set -euo pipefail

cd "$(dirname "$0")/.."
xcodegen generate -q
xcodebuild -project Carafe.xcodeproj -scheme Carafe -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build-release build -quiet

APP=build-release/Build/Products/Release/Carafe.app
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
rm -f dist/Carafe.dmg
hdiutil create -volname "Carafe" -srcfolder "$STAGE" -ov -format UDZO dist/Carafe.dmg -quiet
rm -rf "$STAGE"
echo "DMG prêt : dist/Carafe.dmg"
