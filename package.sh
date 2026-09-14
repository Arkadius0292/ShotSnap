#!/bin/bash
# Сборка дистрибутивов ShotSnap: dist/ShotSnap.dmg, dist/ShotSnap.zip и контрольные суммы.
#
# Режим подписи выбирается автоматически:
#
# 1. Developer ID + нотаризация Apple — если в связке ключей есть сертификат
#    «Developer ID Application: …». Приложение подписывается с Hardened Runtime,
#    .app и .dmg проходят нотаризацию и получают степлированный тикет.
#    Разовая настройка учётных данных нотаризации:
#      xcrun notarytool store-credentials shotsnap-notary \
#        --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
#    Переопределения: SHOTSNAP_SIGN_IDENTITY, SHOTSNAP_NOTARY_PROFILE.
#
# 2. Ad-hoc (сертификата нет) — подпись из build.sh. Gatekeeper блокирует запуск
#    скачанного браузером приложения, поэтому в окно DMG идёт фон с подсказкой
#    первого запуска, а рекомендуемые пути установки — install-shotsnap.sh и Homebrew tap.
#    Принудительно: SHOTSNAP_SIGN_MODE=adhoc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP="ShotSnap.app"
DMG="dist/ShotSnap.dmg"
ZIP="dist/ShotSnap.zip"
NOTARY_PROFILE="${SHOTSNAP_NOTARY_PROFILE:-shotsnap-notary}"

detect_identity() {
    if [ -n "${SHOTSNAP_SIGN_IDENTITY:-}" ]; then
        echo "$SHOTSNAP_SIGN_IDENTITY"
        return
    fi
    security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1
}

SIGN_MODE="${SHOTSNAP_SIGN_MODE:-auto}"
IDENTITY=""
if [ "$SIGN_MODE" != "adhoc" ]; then
    IDENTITY="$(detect_identity)"
fi
if [ -n "$IDENTITY" ]; then
    SIGN_MODE="developer-id"
elif [ "$SIGN_MODE" = "developer-id" ]; then
    echo "❌ SHOTSNAP_SIGN_MODE=developer-id, но сертификат «Developer ID Application» не найден." >&2
    exit 1
else
    SIGN_MODE="adhoc"
fi

notarize() {
    echo "📨 Нотаризация $(basename "$1") (обычно 1–5 минут)..."
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}

if [ "$SIGN_MODE" = "developer-id" ] && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "❌ Профиль нотаризации «$NOTARY_PROFILE» не настроен или недоступен." >&2
    echo "   Выполните: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id … --team-id … --password …" >&2
    echo "   Подпись Developer ID без нотаризации Gatekeeper всё равно не пропустит." >&2
    exit 1
fi

echo "🔨 Сборка актуального приложения..."
"$SCRIPT_DIR/build.sh"

echo "📦 Подготовка дистрибутивов (DMG и ZIP)..."
rm -rf dist
mkdir -p dist/dmg_staging

if [ "$SIGN_MODE" = "developer-id" ]; then
    echo "🔐 Режим подписи: Developer ID — $IDENTITY"
    echo "🔏 Подпись с Hardened Runtime и доверенной меткой времени..."
    codesign --force --timestamp --options runtime \
        --entitlements "$SCRIPT_DIR/ShotSnap.entitlements" \
        --sign "$IDENTITY" "$APP"
    codesign --verify --strict --deep --verbose=2 "$APP"

    # .app нотаризуется отдельно и получает свой тикет: скопированное из DMG
    # приложение проходит Gatekeeper и без сети.
    ditto -c -k --keepParent "$APP" dist/notarize_app.zip
    notarize dist/notarize_app.zip
    rm -f dist/notarize_app.zip
    xcrun stapler staple "$APP"

    DMG_BACKGROUND="$SCRIPT_DIR/Sources/Resources/dmg_background.png"
else
    echo "⚠️  Режим подписи: ad-hoc (Developer ID не найден)."
    echo "   Скачанный браузером DMG Gatekeeper заблокирует — в окно DMG добавлена подсказка первого запуска."
    DMG_BACKGROUND="$SCRIPT_DIR/Sources/Resources/dmg_background_unsigned.png"
fi

cp -R "$APP" dist/dmg_staging/

build_dmg() {
create-dmg \
  --volname "ShotSnap" \
  --volicon "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" \
  --background "$DMG_BACKGROUND" \
  --window-pos 200 120 \
  --window-size 660 440 \
  --icon-size 128 \
  --text-size 13 \
  --icon "ShotSnap.app" 180 180 \
  --hide-extension "ShotSnap.app" \
  --app-drop-link 480 180 \
  --format UDZO \
  --overwrite \
  "$DMG" \
  dist/dmg_staging
}

echo "📀 Сборка Apple-Grade DMG инсталлятора через create-dmg..."
# create-dmg иногда не может отмонтировать временный том («он сейчас используется» —
# Finder/Spotlight ещё держат его): отмонтируем остатки принудительно и пробуем ещё раз.
if ! build_dmg; then
    echo "🔁 create-dmg не справился, повтор..."
    for vol in /Volumes/dmg.*; do
        [ -d "$vol" ] && hdiutil detach "$vol" -force || true
    done
    rm -f dist/rw.*.dmg
    build_dmg
fi

rm -rf dist/dmg_staging

if [ "$SIGN_MODE" = "developer-id" ]; then
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
    notarize "$DMG"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
    spctl --assess --type execute --verbose=2 "$APP"
fi

echo "🗜️ Создание ZIP-архива..."
# ditto, а не zip: так Apple рекомендует упаковывать подписанные бандлы.
ditto -c -k --keepParent "$APP" "$ZIP"

echo "🔢 Контрольные суммы SHA-256..."
(cd dist && shasum -a 256 ShotSnap.zip > ShotSnap.zip.sha256 && shasum -a 256 ShotSnap.dmg > ShotSnap.dmg.sha256)

echo ""
echo "✅ Дистрибутивы готовы в папке dist/ (подпись: $SIGN_MODE):"
echo "   📀 $DMG ($(du -sh "$DMG" | cut -f1))"
echo "   🗜️  $ZIP ($(du -sh "$ZIP" | cut -f1))"
echo "   🔢 sha256(ShotSnap.zip) = $(cut -d' ' -f1 dist/ShotSnap.zip.sha256)"
