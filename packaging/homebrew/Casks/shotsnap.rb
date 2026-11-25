cask "shotsnap" do
  version "1.3.9"
  sha256 "05503c076b32ca1a5e0353bfb2d482a1ac2ef7152546b7b8fca903693e0ce5c2"

  url "https://github.com/Arkadius0292/ShotSnap/releases/download/v#{version}/ShotSnap.zip"
  name "ShotSnap"
  desc "Native screenshot tool with annotations, AI secret masking and OCR"
  homepage "https://kulesh.pro/products/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :big_sur

  app "ShotSnap.app"

  # Сборка подписана ad-hoc и не нотаризована Apple. Homebrew ставит на загрузку
  # атрибут com.apple.quarantine, и Gatekeeper заблокировал бы первый запуск —
  # поэтому tap снимает карантин сам (флаг --no-quarantine удалён в Homebrew 5).
  # Когда появится подпись Developer ID с нотаризацией, этот блок нужно убрать.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/ShotSnap.app"]
  end

  uninstall quit: "com.kuleshav.shotsnap"

  zap trash: [
    "~/Library/Preferences/com.kuleshav.shotsnap.plist",
    "~/Library/Saved Application State/com.kuleshav.shotsnap.savedState",
  ]

  caveats <<~EOS
    ShotSnap живёт в строке меню. Скриншот — Option + Z (⌥Z).
    При первом снимке разрешите доступ к записи экрана:
      Системные настройки → Конфиденциальность и безопасность → Запись экрана
  EOS
end
