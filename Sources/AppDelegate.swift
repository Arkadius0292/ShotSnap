import Cocoa
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var activeEditorController: EditorWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotKey()
        setupScreenNotifications()
        
        let hasPerm = CGPreflightScreenCaptureAccess()
        logSnap("🚀 ShotSnap запущен (статус записи экрана: \(hasPerm), мониторов: \(NSScreen.screens.count)). Готов к работе.")
    }
    
    private func setupScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenParametersDidChange() {
        let screens = NSScreen.screens
        logSnap("🔌 Изменение подключения мониторов! Доступно экранов: \(screens.count)")
        for (i, s) in screens.enumerated() {
            logSnap("   🖥 Экран \(i): frame=\(s.frame), scale=\(s.backingScaleFactor)")
        }
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        if #available(macOS 11.0, *), let img = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ShotSnap") {
            button.image = img
        } else {
            button.title = "📸"
        }
        
        let menu = NSMenu()
        
        let captureItem = NSMenuItem(title: "Сделать скриншот (⌥Z)", action: #selector(triggerCapture), keyEquivalent: "z")
        captureItem.keyEquivalentModifierMask = [.option]
        captureItem.target = self
        menu.addItem(captureItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let permItem = NSMenuItem(title: "Настройки записи экрана...", action: #selector(requestPermissions), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)
        
        let logItem = NSMenuItem(title: "Показать лог (/tmp/shotsnap.log)", action: #selector(openLog), keyEquivalent: "")
        logItem.target = self
        menu.addItem(logItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let infoItem = NSMenuItem(title: "ShotSnap v1.5", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Завершить ShotSnap", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func setupHotKey() {
        HotKeyManager.shared.onHotKeyPressed = { [weak self] in
            logSnap("⚡️ Получен сигнал глобального хоткея Option+Z")
            self?.triggerCapture()
        }
        HotKeyManager.shared.register()
    }
    
    @objc func requestPermissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func openLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/shotsnap.log"))
    }
    
    @objc func triggerCapture() {
        if let existing = activeEditorController {
            logSnap("🔄 Закрываем предыдущее окно редактора")
            existing.close()
            activeEditorController = nil
        }
        
        // Track mouse screen on hotkey press
        let triggerMousePos = NSEvent.mouseLocation
        let triggerScreen = NSScreen.screens.first { NSMouseInRect(triggerMousePos, $0.frame, false) }
        
        CaptureManager.shared.captureInteractive { [weak self] capturedImage in
            guard let self = self, let image = capturedImage else {
                logSnap("ℹ️ Захват отменен или изображение не получено")
                return
            }
            
            // Re-validate against the freshest NSScreen.screens list
            let releaseMousePos = NSEvent.mouseLocation
            let currentScreens = NSScreen.screens
            
            let finalScreen = currentScreens.first { NSMouseInRect(releaseMousePos, $0.frame, false) }
                ?? triggerScreen.flatMap { ts in currentScreens.first { $0.frame == ts.frame } }
                ?? NSScreen.main
                ?? currentScreens.first
            
            logSnap("🎨 Открываем окно редактора на экране: frame=\(String(describing: finalScreen?.frame))")
            
            DispatchQueue.main.async {
                let editor = EditorWindowController(image: image, targetScreen: finalScreen)
                self.activeEditorController = editor
                
                editor.onWindowDidClose = { [weak self] in
                    logSnap("🚪 Окно редактора закрыто")
                    self?.activeEditorController = nil
                }
                
                editor.showWindow(nil)
                if let panel = editor.window as? NSPanel {
                    panel.makeKeyAndOrderFront(nil)
                    panel.orderFrontRegardless()
                } else {
                    editor.window?.makeKeyAndOrderFront(nil)
                    editor.window?.orderFrontRegardless()
                }
                
                logSnap("✨ Окно редактора успешно отображено на целевом экране поверх всех окон и Full-Screen Spaces!")
            }
        }
    }
    
    @objc private func quitApp() {
        logSnap("🛑 Завершение работы ShotSnap")
        NSApp.terminate(nil)
    }
}
