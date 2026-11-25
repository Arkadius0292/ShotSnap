#!/bin/bash
# Регрессионный тест буфера обмена: собирает ImageRenderer + тест и проверяет типы NSPasteboard.
# Затирает содержимое общего буфера обмена на время теста.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)/clipboard_test"
swiftc -O Sources/ImageRenderer.swift Sources/Annotation.swift Sources/CanvasView.swift Sources/IconFactory.swift \
    Sources/SensitiveDataDetector.swift Sources/PreferencesManager.swift scripts/clipboard_test/main.swift \
    -o "$OUT" -framework Cocoa -framework CoreGraphics -framework CoreImage -framework Vision
"$OUT"
echo "--- osascript: clipboard info ---"
osascript -e 'clipboard info'
