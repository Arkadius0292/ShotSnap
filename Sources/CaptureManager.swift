import Cocoa

func logSnap(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(stamp)] \(message)\n"
    print(line, terminator: "")
    if let data = line.data(using: .utf8) {
        if let handle = FileHandle(forWritingAtPath: "/tmp/shotsnap.log") {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: "/tmp/shotsnap.log"))
        }
    }
}

final class CaptureManager {
    static let shared = CaptureManager()
    
    private var isCapturing = false
    
    private init() {}
    
    func captureInteractive(completion: @escaping (NSImage?) -> Void) {
        guard !isCapturing else {
            logSnap("⚠️ Захват экрана уже выполняется")
            return
        }
        
        isCapturing = true
        logSnap("📸 Начат интерактивный захват экрана...")
        
        let tempFilePath = "/tmp/shotsnap_\(UUID().uuidString).png"
        let tempURL = URL(fileURLWithPath: tempFilePath)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                DispatchQueue.main.async {
                    self?.isCapturing = false
                }
            }
            
            // Brief 100ms pause to ensure modifier keys are cleanly released
            usleep(100_000)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: interactive (drag or Space for window)
            process.arguments = ["-i", tempFilePath]
            
            let errPipe = Pipe()
            process.standardError = errPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !errStr.isEmpty {
                    logSnap("⚠️ screencapture stderr: \(errStr)")
                }
                
                logSnap("⚙️ screencapture завершился с кодом \(process.terminationStatus)")
                
                let fileExists = FileManager.default.fileExists(atPath: tempFilePath)
                logSnap("📁 Временный файл существует: \(fileExists)")
                
                guard process.terminationStatus == 0,
                      fileExists,
                      let data = try? Data(contentsOf: tempURL),
                      !data.isEmpty else {
                    logSnap("❌ Снимок отменен (Esc) или файл не создан")
                    try? FileManager.default.removeItem(at: tempURL)
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                logSnap("📦 Считано \(data.count) байт из снимка")
                
                guard let image = NSImage(data: data) else {
                    logSnap("❌ Не удалось создать NSImage из считанных данных")
                    try? FileManager.default.removeItem(at: tempURL)
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                logSnap("✅ NSImage успешно создан, размер: \(image.size)")
                
                // Cleanup temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                DispatchQueue.main.async {
                    completion(image)
                }
            } catch {
                logSnap("❌ Исключение при запуске screencapture: \(error)")
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
