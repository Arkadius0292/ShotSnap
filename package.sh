#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Сборка актуального приложения..."
"$SCRIPT_DIR/build.sh"

echo "📦 Подготовка дистрибутивов (DMG и ZIP)..."
rm -rf dist
mkdir -p dist/dmg_staging

cp -R ShotSnap.app dist/dmg_staging/

echo "📀 Сборка Apple-Grade DMG инсталлятора через create-dmg..."
create-dmg \
  --volname "ShotSnap" \
  --volicon "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" \
  --background "$SCRIPT_DIR/Sources/Resources/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 660 440 \
  --icon-size 128 \
  --text-size 13 \
  --icon "ShotSnap.app" 180 180 \
  --hide-extension "ShotSnap.app" \
  --app-drop-link 480 180 \
  --format UDZO \
  --overwrite \
  dist/ShotSnap.dmg \
  dist/dmg_staging

rm -rf dist/dmg_staging

echo "🗜️ Создание ZIP-архива..."
zip -r -y dist/ShotSnap.zip ShotSnap.app

echo ""
echo "✅ Дистрибутивы готовы в папке dist/:"
echo "   📀 dist/ShotSnap.dmg ($(du -sh dist/ShotSnap.dmg | cut -f1))"
echo "   🗜️  dist/ShotSnap.zip ($(du -sh dist/ShotSnap.zip | cut -f1))"
