import Cocoa
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    var onHotKeyPressed: (() -> Void)?
    
    private init() {
        installHandler()
    }
    
    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr && hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    HotKeyManager.shared.onHotKeyPressed?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            nil
        )
    }
    
    func register(preset: HotKeyPreset) {
        register(keyCode: preset.keyCode, modifiers: preset.carbonModifiers, description: preset.title)
    }
    
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_Z), modifiers: UInt32 = UInt32(optionKey), description: String = "⌥Z (Option + Z)") {
        unregister()
        
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x534E4150), // 'SNAP'
            id: 1
        )
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            logSnap("❌ Ошибка регистрации хоткея \(description): status=\(status)")
        } else {
            logSnap("⚡️ Глобальный хоткей [\(description)] успешно зарегистрирован!")
        }
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    deinit {
        unregister()
    }
}
