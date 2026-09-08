import Cocoa
import Carbon

enum HotKeyPreset: String, CaseIterable {
    case optionZ = "opt_z"
    case optionS = "opt_s"
    case shiftCmd1 = "shift_cmd_1"
    case optionX = "opt_x"
    case optionC = "opt_c"
    case shiftCmdS = "shift_cmd_s"
    case shiftCmdZ = "shift_cmd_z"
    case controlOptionA = "ctrl_opt_a"
    
    var title: String {
        switch self {
        case .optionZ: return "⌥Z (Option + Z) — по умолчанию"
        case .optionS: return "⌥S (Option + S)"
        case .shiftCmd1: return "⇧⌘1 (Shift + Command + 1)"
        case .optionX: return "⌥X (Option + X)"
        case .optionC: return "⌥C (Option + C)"
        case .shiftCmdS: return "⇧⌘S (Shift + Command + S)"
        case .shiftCmdZ: return "⇧⌘Z (Shift + Command + Z)"
        case .controlOptionA: return "⌃⌥A (Control + Option + A)"
        }
    }
    
    var displayShortcut: String {
        switch self {
        case .optionZ: return "⌥Z"
        case .optionS: return "⌥S"
        case .shiftCmd1: return "⇧⌘1"
        case .optionX: return "⌥X"
        case .optionC: return "⌥C"
        case .shiftCmdS: return "⇧⌘S"
        case .shiftCmdZ: return "⇧⌘Z"
        case .controlOptionA: return "⌃⌥A"
        }
    }
    
    var keyCode: UInt32 {
        switch self {
        case .optionZ: return UInt32(kVK_ANSI_Z)
        case .optionS: return UInt32(kVK_ANSI_S)
        case .shiftCmd1: return UInt32(kVK_ANSI_1)
        case .optionX: return UInt32(kVK_ANSI_X)
        case .optionC: return UInt32(kVK_ANSI_C)
        case .shiftCmdS: return UInt32(kVK_ANSI_S)
        case .shiftCmdZ: return UInt32(kVK_ANSI_Z)
        case .controlOptionA: return UInt32(kVK_ANSI_A)
        }
    }
    
    var carbonModifiers: UInt32 {
        switch self {
        case .optionZ, .optionS, .optionX, .optionC:
            return UInt32(optionKey)
        case .shiftCmd1, .shiftCmdS, .shiftCmdZ:
            return UInt32(shiftKey | cmdKey)
        case .controlOptionA:
            return UInt32(controlKey | optionKey)
        }
    }
    
    var keyEquivalent: String {
        switch self {
        case .optionZ, .shiftCmdZ: return "z"
        case .optionS, .shiftCmdS: return "s"
        case .shiftCmd1: return "1"
        case .optionX: return "x"
        case .optionC: return "c"
        case .controlOptionA: return "a"
        }
    }
    
    var modifierMask: NSEvent.ModifierFlags {
        switch self {
        case .optionZ, .optionS, .optionX, .optionC:
            return [.option]
        case .shiftCmd1, .shiftCmdS, .shiftCmdZ:
            return [.shift, .command]
        case .controlOptionA:
            return [.control, .option]
        }
    }
}

final class PreferencesManager {
    static let shared = PreferencesManager()
    
    private let colorIndexKey = "ShotSnap_ColorIndex"
    private let sizeIndexKey = "ShotSnap_SizeIndex"
    private let hotKeyPresetKey = "ShotSnap_HotKeyPreset"
    
    private init() {}
    
    var hotKeyPreset: HotKeyPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: hotKeyPresetKey),
                  let preset = HotKeyPreset(rawValue: raw) else {
                return .optionZ
            }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: hotKeyPresetKey)
        }
    }
    
    var savedColorIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: colorIndexKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: colorIndexKey)
        }
    }
    
    var savedSizeIndex: Int {
        get {
            // Default to middle preset (index 1) if not set
            if UserDefaults.standard.object(forKey: sizeIndexKey) == nil {
                return 1
            }
            return UserDefaults.standard.integer(forKey: sizeIndexKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sizeIndexKey)
        }
    }
}
