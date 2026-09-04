#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Компиляция ShotSnap..."

mkdir -p build

swiftc -O \
    Sources/IconFactory.swift \
    Sources/SensitiveDataDetector.swift \
    Sources/HotKeyManager.swift \
    Sources/CaptureManager.swift \
    Sources/OCRManager.swift \
    Sources/PreferencesManager.swift \
    Sources/Annotation.swift \
    Sources/CanvasView.swift \
    Sources/ToolbarView.swift \
    Sources/ImageRenderer.swift \
    Sources/EditorWindowController.swift \
    Sources/AppDelegate.swift \
    Sources/main.swift \
    -o build/ShotSnap \
    -framework Cocoa \
    -framework Carbon \
    -framework CoreGraphics \
    -framework CoreImage \
    -framework Vision

echo "📦 Сборка бандла ShotSnap.app..."

APP_DIR="ShotSnap.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp build/ShotSnap "$APP_DIR/Contents/MacOS/ShotSnap"
cp Info.plist "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/ShotSnap"

echo "🔏 Подпись бандла стабильным идентификатором com.kuleshav.shotsnap..."
codesign -f -s - --identifier "com.kuleshav.shotsnap" --requirements '=designated => identifier "com.kuleshav.shotsnap"' "$APP_DIR"

echo "✅ Успешно собрано: $SCRIPT_DIR/ShotSnap.app"
