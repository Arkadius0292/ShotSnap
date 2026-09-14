#!/bin/bash
# Подставляет версию из Info.plist и SHA-256 из dist/ShotSnap.zip в cask-файл.
#
#   ./scripts/update_homebrew_cask.sh                       # правит packaging/homebrew/Casks/shotsnap.rb
#   ./scripts/update_homebrew_cask.sh ~/src/homebrew-shotsnap   # и копирует его в checkout tap-репозитория
#
# Запускать после ./package.sh: хэш должен совпасть с тем ZIP, что загружен в GitHub Release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

CASK="packaging/homebrew/Casks/shotsnap.rb"
ZIP="dist/ShotSnap.zip"

[ -f "$ZIP" ] || { echo "❌ Нет $ZIP — сначала ./package.sh" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

sed -i '' -E \
    -e "s/^  version \"[^\"]*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \"[^\"]*\"/  sha256 \"$SHA\"/" \
    "$CASK"

echo "✅ $CASK → version $VERSION, sha256 $SHA"

if [ $# -ge 1 ]; then
    mkdir -p "$1/Casks"
    cp "$CASK" "$1/Casks/shotsnap.rb"
    echo "📋 Скопировано в $1/Casks/shotsnap.rb — закоммитьте и запушьте tap-репозиторий."
fi
