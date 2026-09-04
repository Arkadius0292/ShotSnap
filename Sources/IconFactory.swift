import Cocoa

final class IconFactory {
    
    // MARK: - 3D Claymorphic Icon Loader
    private static var iconCache: [String: NSImage] = [:]
    
    static func load3DIcon(name: String, targetSize: CGSize) -> NSImage? {
        let cacheKey = "\(name)_\(Int(targetSize.width))x\(Int(targetSize.height))"
        if let cached = iconCache[cacheKey] {
            return cached
        }
        
        var foundPath: String?
        
        if let p = Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Icons") {
            foundPath = p
        } else if let p = Bundle.main.path(forResource: name, ofType: "png") {
            foundPath = p
        } else {
            // Development and fallback search paths
            let candidates = [
                "Sources/Resources/Icons/\(name).png",
                "../Sources/Resources/Icons/\(name).png",
                Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Icons/\(name).png").path,
                Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).png").path
            ]
            for candidate in candidates {
                if FileManager.default.fileExists(atPath: candidate) {
                    foundPath = candidate
                    break
                }
            }
        }
        
        guard let p = foundPath, let image = NSImage(contentsOfFile: p) else {
            return nil
        }
        
        image.size = targetSize
        image.isTemplate = false
        iconCache[cacheKey] = image
        return image
    }
    
    // MARK: - Tool Vector Icons
    static func createSelectIcon() -> NSImage {
        if let img = load3DIcon(name: "select", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        // 4-Way Move Crosshair (Перекрестье перемещения и выбора)
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Оси перекрестья
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 9.0, y: 2.2))
            ctx.addLine(to: CGPoint(x: 9.0, y: 15.8))
            ctx.move(to: CGPoint(x: 2.2, y: 9.0))
            ctx.addLine(to: CGPoint(x: 15.8, y: 9.0))
            ctx.strokePath()
            
            // 4 стрелки на концах осей
            ctx.beginPath()
            // Вверх
            ctx.move(to: CGPoint(x: 6.8, y: 13.5))
            ctx.addLine(to: CGPoint(x: 9.0, y: 16.5))
            ctx.addLine(to: CGPoint(x: 11.2, y: 13.5))
            // Вниз
            ctx.move(to: CGPoint(x: 6.8, y: 4.5))
            ctx.addLine(to: CGPoint(x: 9.0, y: 1.5))
            ctx.addLine(to: CGPoint(x: 11.2, y: 4.5))
            // Влево
            ctx.move(to: CGPoint(x: 4.5, y: 11.2))
            ctx.addLine(to: CGPoint(x: 1.5, y: 9.0))
            ctx.addLine(to: CGPoint(x: 4.5, y: 6.8))
            // Вправо
            ctx.move(to: CGPoint(x: 13.5, y: 11.2))
            ctx.addLine(to: CGPoint(x: 16.5, y: 9.0))
            ctx.addLine(to: CGPoint(x: 13.5, y: 6.8))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createArrowIcon() -> NSImage {
        if let img = load3DIcon(name: "arrow", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        // Классическая прямая диагональная стрелка 45°
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Прямой диагональный стержень
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 3.5, y: 3.5))
            ctx.addLine(to: CGPoint(x: 14.5, y: 14.5))
            ctx.strokePath()
            
            // Симметричное острое оперение
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 8.5, y: 14.5))
            ctx.addLine(to: CGPoint(x: 15.0, y: 15.0))
            ctx.addLine(to: CGPoint(x: 14.5, y: 8.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createRectIcon() -> NSImage {
        if let img = load3DIcon(name: "rect", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.8)
            let rect = CGRect(x: 2.5, y: 2.5, width: 13.0, height: 13.0)
            let path = CGPath(roundedRect: rect, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }
    
    static func createPenIcon() -> NSImage {
        if let img = load3DIcon(name: "pen", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        // Художественная кисть (ворсистый кончик, обойма, черенок)
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // 1. Ворс кисти
            let bristle = CGMutablePath()
            bristle.move(to: CGPoint(x: 2.0, y: 2.0))
            bristle.addQuadCurve(to: CGPoint(x: 7.2, y: 8.8), control: CGPoint(x: 2.0, y: 6.2))
            bristle.addLine(to: CGPoint(x: 8.8, y: 7.2))
            bristle.addQuadCurve(to: CGPoint(x: 2.0, y: 2.0), control: CGPoint(x: 6.2, y: 2.0))
            bristle.closeSubpath()
            ctx.addPath(bristle)
            ctx.fillPath()
            
            // 2. Металлическая обойма
            let ferrule = CGMutablePath()
            ferrule.move(to: CGPoint(x: 6.8, y: 9.2))
            ferrule.addLine(to: CGPoint(x: 10.2, y: 12.6))
            ferrule.addLine(to: CGPoint(x: 11.6, y: 11.2))
            ferrule.addLine(to: CGPoint(x: 8.2, y: 7.8))
            ferrule.closeSubpath()
            ctx.addPath(ferrule)
            ctx.strokePath()
            
            // 3. Деревянный черенок
            let handle = CGMutablePath()
            handle.move(to: CGPoint(x: 10.2, y: 12.6))
            handle.addLine(to: CGPoint(x: 15.0, y: 16.5))
            handle.addQuadCurve(to: CGPoint(x: 16.5, y: 15.0), control: CGPoint(x: 16.5, y: 16.5))
            handle.addLine(to: CGPoint(x: 11.6, y: 11.2))
            handle.closeSubpath()
            ctx.addPath(handle)
            ctx.fillPath()
            
            ctx.restoreGState()
        }
    }
    
    static func createHighlighterIcon() -> NSImage {
        if let img = load3DIcon(name: "highlighter", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        // Скошенный маркер с выделительной черточкой
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.4)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Корпус маркера
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 5.8, y: 8.8))
            body.addLine(to: CGPoint(x: 11.5, y: 14.5))
            body.addLine(to: CGPoint(x: 14.5, y: 11.5))
            body.addLine(to: CGPoint(x: 8.8, y: 5.8))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.strokePath()
            
            // Скошенное перо
            let tip = CGMutablePath()
            tip.move(to: CGPoint(x: 5.8, y: 8.8))
            tip.addLine(to: CGPoint(x: 4.0, y: 7.0))
            tip.addLine(to: CGPoint(x: 7.0, y: 5.0))
            tip.addLine(to: CGPoint(x: 8.8, y: 5.8))
            tip.closeSubpath()
            ctx.addPath(tip)
            ctx.fillPath()
            
            // Выделительная черточка снизу
            ctx.setLineWidth(2.4)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 2.0, y: 2.5))
            ctx.addLine(to: CGPoint(x: 16.0, y: 2.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createTextIcon() -> NSImage {
        if let img = load3DIcon(name: "text", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            let font = NSFont.systemFont(ofSize: 15.0, weight: .bold)
            let attr: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "T", attributes: attr)
            let size = str.size()
            let origin = CGPoint(x: (18 - size.width) / 2, y: (18 - size.height) / 2 - 0.5)
            
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            str.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
            
            ctx.restoreGState()
        }
    }
    
    static func createStepIcon() -> NSImage {
        if let img = load3DIcon(name: "step", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.strokeEllipse(in: CGRect(x: 2.0, y: 2.0, width: 14.0, height: 14.0))
            
            let font = NSFont.boldSystemFont(ofSize: 11.0)
            let attr: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "1", attributes: attr)
            let size = str.size()
            let origin = CGPoint(x: (18 - size.width) / 2, y: (18 - size.height) / 2 - 0.5)
            
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            str.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
            
            ctx.restoreGState()
        }
    }
    
    // MARK: - Mask 1: Manual Mask / Blur (Ручная маска)
    static func createManualMaskIcon() -> NSImage {
        if let img = load3DIcon(name: "blur", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 20, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Venetian Mask Silhouette
            let mask = CGMutablePath()
            mask.move(to: CGPoint(x: 1.5, y: 11.0))
            mask.addQuadCurve(to: CGPoint(x: 10.0, y: 15.0), control: CGPoint(x: 5.0, y: 15.5))
            mask.addQuadCurve(to: CGPoint(x: 18.5, y: 11.0), control: CGPoint(x: 15.0, y: 15.5))
            mask.addQuadCurve(to: CGPoint(x: 16.5, y: 5.0), control: CGPoint(x: 19.0, y: 7.0))
            mask.addQuadCurve(to: CGPoint(x: 10.0, y: 8.0), control: CGPoint(x: 13.5, y: 4.5))
            mask.addQuadCurve(to: CGPoint(x: 3.5, y: 5.0), control: CGPoint(x: 6.5, y: 4.5))
            mask.addQuadCurve(to: CGPoint(x: 1.5, y: 11.0), control: CGPoint(x: 1.0, y: 7.0))
            mask.closeSubpath()
            ctx.addPath(mask)
            ctx.strokePath()
            
            // Left eye hole
            let leftEye = CGMutablePath()
            leftEye.addEllipse(in: CGRect(x: 4.2, y: 8.5, width: 3.8, height: 2.8))
            ctx.addPath(leftEye)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            // Right eye hole
            let rightEye = CGMutablePath()
            rightEye.addEllipse(in: CGRect(x: 12.0, y: 8.5, width: 3.8, height: 2.8))
            ctx.addPath(rightEye)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            ctx.restoreGState()
        }
    }
    
    // MARK: - Mask 2: AI Smart Redact Mask (Монохромная AI-Маска с буквами AI)
    static func createAIMaskIcon() -> NSImage {
        if let img = load3DIcon(name: "ai_mask", targetSize: CGSize(width: 22, height: 22)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 20, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Единый силуэт венецианской маски
            let mask = CGMutablePath()
            mask.move(to: CGPoint(x: 1.5, y: 11.0))
            mask.addQuadCurve(to: CGPoint(x: 10.0, y: 15.0), control: CGPoint(x: 5.0, y: 15.5))
            mask.addQuadCurve(to: CGPoint(x: 18.5, y: 11.0), control: CGPoint(x: 15.0, y: 15.5))
            mask.addQuadCurve(to: CGPoint(x: 16.5, y: 5.0), control: CGPoint(x: 19.0, y: 7.0))
            mask.addQuadCurve(to: CGPoint(x: 10.0, y: 8.0), control: CGPoint(x: 13.5, y: 4.5))
            mask.addQuadCurve(to: CGPoint(x: 3.5, y: 5.0), control: CGPoint(x: 6.5, y: 4.5))
            mask.addQuadCurve(to: CGPoint(x: 1.5, y: 11.0), control: CGPoint(x: 1.0, y: 7.0))
            mask.closeSubpath()
            ctx.addPath(mask)
            ctx.strokePath()
            
            // Глазки
            let leftEye = CGMutablePath()
            leftEye.addEllipse(in: CGRect(x: 3.8, y: 8.2, width: 3.5, height: 2.5))
            ctx.addPath(leftEye)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            let rightEye = CGMutablePath()
            rightEye.addEllipse(in: CGRect(x: 12.7, y: 8.2, width: 3.5, height: 2.5))
            ctx.addPath(rightEye)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            // Четкие буквы AI по центру переносицы
            let font = NSFont.systemFont(ofSize: 7.2, weight: .black)
            let attr: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "AI", attributes: attr)
            let sz = str.size()
            
            NSGraphicsContext.saveGraphicsState()
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.current = nsCtx
            str.draw(at: CGPoint(x: (20.0 - sz.width) / 2.0, y: 6.8))
            NSGraphicsContext.restoreGraphicsState()
            
            ctx.restoreGState()
        }
    }
    
    // MARK: - Action Button Icons (Clean vector graphics)
    static func createCopyIcon() -> NSImage {
        if let img = load3DIcon(name: "copy", targetSize: CGSize(width: 20, height: 20)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Clipboard board
            let board = CGRect(x: 2.0, y: 1.5, width: 12.0, height: 13.0)
            let path = CGPath(roundedRect: board, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            ctx.addPath(path)
            ctx.strokePath()
            
            // Clip
            let clip = CGRect(x: 5.5, y: 12.5, width: 5.0, height: 2.5)
            ctx.addPath(CGPath(roundedRect: clip, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.strokePath()
            
            // Checkmark inside
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4.5, y: 7.0))
            ctx.addLine(to: CGPoint(x: 7.0, y: 4.5))
            ctx.addLine(to: CGPoint(x: 11.5, y: 9.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createPasteIcon() -> NSImage {
        if let img = load3DIcon(name: "paste", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Back clipboard
            let back = CGRect(x: 1.5, y: 3.5, width: 10.0, height: 11.5)
            ctx.addPath(CGPath(roundedRect: back, cornerWidth: 2.0, cornerHeight: 2.0, transform: nil))
            ctx.strokePath()
            
            // Front sheet
            let front = CGRect(x: 5.0, y: 1.0, width: 9.5, height: 11.0)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(CGPath(roundedRect: front, cornerWidth: 2.0, cornerHeight: 2.0, transform: nil))
            ctx.fillPath()
            ctx.strokePath()
            
            // Arrow down into sheet
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 9.7, y: 9.0))
            ctx.addLine(to: CGPoint(x: 9.7, y: 4.0))
            ctx.move(to: CGPoint(x: 7.5, y: 6.0))
            ctx.addLine(to: CGPoint(x: 9.7, y: 3.8))
            ctx.addLine(to: CGPoint(x: 12.0, y: 6.0))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createUndoIcon() -> NSImage {
        if let img = load3DIcon(name: "undo", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Arrow tip
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 2.0, y: 10.5))
            ctx.addLine(to: CGPoint(x: 6.0, y: 14.5))
            ctx.move(to: CGPoint(x: 2.0, y: 10.5))
            ctx.addLine(to: CGPoint(x: 6.0, y: 6.5))
            ctx.strokePath()
            
            // Arc
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 2.5, y: 10.5))
            ctx.addQuadCurve(to: CGPoint(x: 14.0, y: 5.5), control: CGPoint(x: 14.0, y: 12.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createBase64Icon() -> NSImage {
        if let img = load3DIcon(name: "base64", targetSize: CGSize(width: 20, height: 20)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Binary Code Brackets: < / >
            // Left bracket <
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4.5, y: 12.5))
            ctx.addLine(to: CGPoint(x: 1.5, y: 8.0))
            ctx.addLine(to: CGPoint(x: 4.5, y: 3.5))
            ctx.strokePath()
            
            // Slash /
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 6.5, y: 3.5))
            ctx.addLine(to: CGPoint(x: 9.5, y: 12.5))
            ctx.strokePath()
            
            // Right bracket >
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 11.5, y: 12.5))
            ctx.addLine(to: CGPoint(x: 14.5, y: 8.0))
            ctx.addLine(to: CGPoint(x: 11.5, y: 3.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createOCRIcon() -> NSImage {
        if let img = load3DIcon(name: "ocr", targetSize: CGSize(width: 20, height: 20)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Document outline
            let doc = CGRect(x: 2.0, y: 1.5, width: 12.0, height: 13.0)
            ctx.addPath(CGPath(roundedRect: doc, cornerWidth: 2.0, cornerHeight: 2.0, transform: nil))
            ctx.strokePath()
            
            // Scan beam line
            ctx.setLineWidth(1.8)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0.5, y: 8.0))
            ctx.addLine(to: CGPoint(x: 15.5, y: 8.0))
            ctx.strokePath()
            
            // Text lines inside
            ctx.setLineWidth(1.2)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4.5, y: 11.0))
            ctx.addLine(to: CGPoint(x: 11.5, y: 11.0))
            ctx.move(to: CGPoint(x: 4.5, y: 4.5))
            ctx.addLine(to: CGPoint(x: 9.5, y: 4.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createCLIIcon() -> NSImage {
        if let img = load3DIcon(name: "cli", targetSize: CGSize(width: 20, height: 20)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Terminal window frame
            let win = CGRect(x: 1.5, y: 1.5, width: 13.0, height: 13.0)
            ctx.addPath(CGPath(roundedRect: win, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            ctx.strokePath()
            
            // Console prompt: > _
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 4.0, y: 10.5))
            ctx.addLine(to: CGPoint(x: 6.5, y: 8.0))
            ctx.addLine(to: CGPoint(x: 4.0, y: 5.5))
            ctx.strokePath()
            
            // Cursor underscore
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 8.5, y: 5.5))
            ctx.addLine(to: CGPoint(x: 11.5, y: 5.5))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createSaveIcon() -> NSImage {
        if let img = load3DIcon(name: "save", targetSize: CGSize(width: 24, height: 24)) {
            return img
        }
        return createTemplateImage(size: CGSize(width: 16, height: 16)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Floppy disk / drive body
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 2.0, y: 2.0))
            body.addLine(to: CGPoint(x: 2.0, y: 14.0))
            body.addLine(to: CGPoint(x: 11.5, y: 14.0))
            body.addLine(to: CGPoint(x: 14.0, y: 11.5))
            body.addLine(to: CGPoint(x: 14.0, y: 2.0))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.strokePath()
            
            // Shutter slider at top
            let slider = CGRect(x: 4.5, y: 8.5, width: 7.0, height: 5.5)
            ctx.stroke(slider)
            
            // Label cutout at bottom
            let label = CGRect(x: 4.5, y: 2.0, width: 7.0, height: 4.5)
            ctx.stroke(label)
            
            ctx.restoreGState()
        }
    }
    
    // MARK: - Helper to generate vector template images
    private static func createTemplateImage(size: CGSize, draw: @escaping (CGContext) -> Void) -> NSImage {
        let image = NSImage(size: size, flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(ctx)
            return true
        }
        image.isTemplate = true
        return image
    }
}
