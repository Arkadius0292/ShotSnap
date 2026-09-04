#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Сборка актуального приложения..."
"$SCRIPT_DIR/build.sh"

echo "📦 Создание дистрибутивов (DMG и ZIP)..."
rm -rf dist
mkdir -p dist/dmg_root

cp -R ShotSnap.app dist/dmg_root/
ln -s /Applications dist/dmg_root/Applications

hdiutil create -volname "ShotSnap" -srcfolder dist/dmg_root -ov -format UDZO dist/ShotSnap.dmg
zip -r -y dist/ShotSnap.zip ShotSnap.app
rm -rf dist/dmg_root

echo ""
echo "✅ Дистрибутивы готовы в папке dist/:"
echo "   📀 dist/ShotSnap.dmg ($(du -sh dist/ShotSnap.dmg | cut -f1))"
echo "   🗜️  dist/ShotSnap.zip ($(du -sh dist/ShotSnap.zip | cut -f1))"
