#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Сборка актуальной версии ShotSnap..."
"$SCRIPT_DIR/build.sh"

echo "📂 Установка ShotSnap в /Applications..."
rm -rf "/Applications/ShotSnap.app"
cp -R "$SCRIPT_DIR/ShotSnap.app" "/Applications/ShotSnap.app"

echo "🚀 Запуск ShotSnap..."
killall ShotSnap 2>/dev/null || true
open "/Applications/ShotSnap.app"

echo ""
echo "🎉 ShotSnap успешно установлен в /Applications и запущен!"
echo "👉 Нажмите Option + Z (⌥Z) в любом месте для проверки создания скриншота."
