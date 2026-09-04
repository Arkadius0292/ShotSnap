import Cocoa

final class ImageRenderer {
    static let persistentPath = "/tmp/shotsnap_latest.png"
    static let userDirPersistentPath = NSString(string: "~/.shotsnap/latest.png").expandingTildeInPath
    
    static func render(
        baseImage: NSImage,
        baseImageRect: CGRect,
        exportRect: CGRect,
        annotations: [BaseAnnotation],
        viewBounds: CGRect
    ) -> (image: NSImage, pngData: Data?) {
        let scale: CGFloat
        if let rep = baseImage.representations.first {
            scale = max(1.0, CGFloat(rep.pixelsWide) / max(baseImageRect.width, 1))
        } else {
            scale = 2.0
        }
        
        let targetWidth = max(1, Int(exportRect.width * scale))
        let targetHeight = max(1, Int(exportRect.height * scale))
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: targetWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return (baseImage, nil)
        }
        
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -exportRect.origin.x, y: -exportRect.origin.y)
        
        // 1. Draw background if expanded
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        
        if exportRect != baseImageRect {
            context.setFillColor(NSColor(white: 0.12, alpha: 1.0).cgColor)
            context.fill(exportRect)
            
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.45).cgColor)
            context.setFillColor(NSColor.black.cgColor)
            let cardPath = CGPath(roundedRect: baseImageRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            context.addPath(cardPath)
            context.fillPath()
            context.restoreGState()
        }
        
        baseImage.draw(in: baseImageRect)
        
        // 2. Draw annotations without selection handles
        for annotation in annotations {
            let wasSelected = annotation.isSelected
            annotation.isSelected = false
            annotation.draw(in: context, baseImage: baseImage, baseImageRect: baseImageRect, viewBounds: viewBounds)
            annotation.isSelected = wasSelected
        }
        
        NSGraphicsContext.restoreGraphicsState()
        
        guard let cgImage = context.makeImage() else {
            return (baseImage, nil)
        }
        
        let finalImage = NSImage(cgImage: cgImage, size: exportRect.size)
        
        // Convert to PNG data
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let pngData = rep.representation(using: .png, properties: [:])
        
        // Auto-save to persistent paths for Terminal / Claude CLI
        if let data = pngData {
            try? data.write(to: URL(fileURLWithPath: persistentPath))
            
            let userDir = (userDirPersistentPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: userDir, withIntermediateDirectories: true)
            try? data.write(to: URL(fileURLWithPath: userDirPersistentPath))
        }
        
        return (finalImage, pngData)
    }
    
    static func copyToClipboard(image: NSImage, pngData: Data?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let pngData = pngData {
            let item = NSPasteboardItem()
            item.setData(pngData, forType: .png)
            if let tiffData = image.tiffRepresentation {
                item.setData(tiffData, forType: .tiff)
            }
            let fileURL = URL(fileURLWithPath: persistentPath)
            item.setString(fileURL.absoluteString, forType: .fileURL)
            
            pasteboard.writeObjects([item])
        } else {
            pasteboard.writeObjects([image])
        }
        
        NSSound(named: "Hero")?.play()
    }
    
    static func copyBase64ToClipboard(pngData: Data?) {
        guard let data = pngData else { return }
        let base64String = data.base64EncodedString()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(base64String, forType: .string)
        NSSound(named: "Hero")?.play()
    }
    
    static func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        NSSound(named: "Hero")?.play()
    }
    
    static func saveToDownloadsAndCopyPath(pngData: Data?) -> String? {
        guard let data = pngData else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateStr = formatter.string(from: Date())
        let fileName = "ShotSnap_\(dateStr).png"
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSString(string: "~/Downloads").expandingTildeInPath)
        let targetURL = downloadsDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: targetURL)
            try? data.write(to: URL(fileURLWithPath: persistentPath))
            
            let path = targetURL.path
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(path, forType: .string)
            
            NSSound(named: "Hero")?.play()
            return path
        } catch {
            print("Error saving to downloads: \(error)")
            return nil
        }
    }
    
    static func copyFilePathToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(persistentPath, forType: .string)
        NSSound(named: "Hero")?.play()
    }
}
