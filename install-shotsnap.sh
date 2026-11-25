#!/bin/bash
# Установка ShotSnap одной командой — без браузерного карантина Gatekeeper:
#
#   curl -fsSL https://raw.githubusercontent.com/Arkadius0292/ShotSnap/main/install-shotsnap.sh | bash
#
# Скрипт скачивает ShotSnap.zip из GitHub Releases через curl (curl, в отличие от
# браузера, не ставит атрибут com.apple.quarantine), сверяет SHA-256 с файлом,
# опубликованным в том же релизе, и устанавливает приложение в /Applications.
#
# Переменные окружения:
#   SHOTSNAP_VERSION=1.3.9      установить конкретную версию вместо последней
#   SHOTSNAP_APPDIR=~/Applications   каталог установки (по умолчанию /Applications)
#
# Весь код обёрнут в main и вызывается последней строкой: если загрузка скрипта
# оборвётся на середине, bash не выполнит недокачанный фрагмент.
set -euo pipefail

main() {
    local repo="Arkadius0292/ShotSnap"
    local app_name="ShotSnap.app"
    local appdir="${SHOTSNAP_APPDIR:-/Applications}"
    local base

    if [ -n "${SHOTSNAP_VERSION:-}" ]; then
        base="https://github.com/${repo}/releases/download/v${SHOTSNAP_VERSION#v}"
    else
        base="https://github.com/${repo}/releases/latest/download"
    fi

    say() { printf '%s\n' "$*"; }
    die() { printf '❌ %s\n' "$*" >&2; exit 1; }

    [ "$(uname -s)" = "Darwin" ] || die "ShotSnap работает только на macOS."

    local macos_major
    macos_major="$(sw_vers -productVersion | cut -d. -f1)"
    [ "$macos_major" -ge 11 ] || die "Нужна macOS 11 Big Sur или новее (у вас $(sw_vers -productVersion))."

    # Сборка пока только под Apple Silicon.
    if [ "$(uname -m)" != "arm64" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" != "1" ]; then
        die "Текущая сборка ShotSnap поддерживает только Mac на Apple Silicon (M1 и новее)."
    fi

    # Глобальная (не local): trap EXIT срабатывает уже после выхода из main.
    SHOTSNAP_TMP="$(mktemp -d "${TMPDIR:-/tmp}/shotsnap-install.XXXXXX")"
    trap 'rm -rf "${SHOTSNAP_TMP:-}"' EXIT
    local tmp="$SHOTSNAP_TMP"

    say "⬇️  Загрузка ShotSnap..."
    curl -fL --proto '=https' --tlsv1.2 --retry 3 --progress-bar -o "$tmp/ShotSnap.zip" "$base/ShotSnap.zip" \
        || die "Не удалось скачать $base/ShotSnap.zip"
    curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$tmp/ShotSnap.zip.sha256" "$base/ShotSnap.zip.sha256" \
        || die "Не удалось скачать контрольную сумму $base/ShotSnap.zip.sha256"

    say "🔢 Проверка SHA-256..."
    local expected actual
    expected="$(awk '{print $1; exit}' "$tmp/ShotSnap.zip.sha256")"
    actual="$(shasum -a 256 "$tmp/ShotSnap.zip" | awk '{print $1}')"
    [ -n "$expected" ] && [ "$expected" = "$actual" ] \
        || die "Контрольная сумма не совпала (ожидалась ${expected:-пусто}, получена $actual). Установка прервана."

    say "📦 Распаковка..."
    ditto -x -k "$tmp/ShotSnap.zip" "$tmp/unpacked"
    [ -d "$tmp/unpacked/$app_name" ] || die "В архиве нет $app_name."
    codesign --verify --strict "$tmp/unpacked/$app_name" 2>/dev/null \
        || die "Подпись $app_name повреждена. Установка прервана."

    local sudo_cmd=""
    mkdir -p "$appdir" 2>/dev/null || true
    if [ ! -w "$appdir" ] || { [ -e "$appdir/$app_name" ] && [ ! -w "$appdir/$app_name" ]; }; then
        say "🔑 Для записи в $appdir нужен пароль администратора."
        sudo_cmd="sudo"
    fi

    if pgrep -x ShotSnap >/dev/null 2>&1; then
        say "🛑 Остановка запущенного ShotSnap..."
        killall ShotSnap 2>/dev/null || true
        sleep 1
    fi

    say "📂 Установка в $appdir..."
    $sudo_cmd rm -rf "$appdir/$app_name"
    $sudo_cmd ditto "$tmp/unpacked/$app_name" "$appdir/$app_name"
    # curl карантин не ставит; снимаем на случай, если его унаследовал временный каталог.
    $sudo_cmd xattr -dr com.apple.quarantine "$appdir/$app_name" 2>/dev/null || true

    local version
    version="$(defaults read "$appdir/$app_name/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '?')"

    say "🚀 Запуск ShotSnap v$version..."
    open "$appdir/$app_name"

    say ""
    say "🎉 ShotSnap v$version установлен: $appdir/$app_name"
    say "👉 Значок появится в строке меню. Скриншот — Option + Z (⌥Z)."
    say "   При первом снимке macOS попросит доступ к записи экрана — разрешите его."
}

main "$@"
