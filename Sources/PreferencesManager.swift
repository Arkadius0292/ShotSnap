import Cocoa

final class PreferencesManager {
    static let shared = PreferencesManager()
    
    private let colorIndexKey = "ShotSnap_ColorIndex"
    private let sizeIndexKey = "ShotSnap_SizeIndex"
    
    private init() {}
    
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
