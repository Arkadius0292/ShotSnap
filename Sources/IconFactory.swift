import Cocoa

final class IconFactory {
    
    // MARK: - Tool Vector Icons
    static func createSelectIcon() -> NSImage {
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 3.5, y: 15.0))
            path.addLine(to: CGPoint(x: 3.5, y: 3.5))
            path.addLine(to: CGPoint(x: 11.5, y: 11.0))
            path.addLine(to: CGPoint(x: 7.5, y: 11.0))
            path.addLine(to: CGPoint(x: 10.5, y: 16.0))
            path.addLine(to: CGPoint(x: 8.5, y: 17.0))
            path.addLine(to: CGPoint(x: 5.5, y: 12.0))
            path.closeSubpath()
            
            ctx.addPath(path)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
    }
    
    static func createArrowIcon() -> NSImage {
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Curved arrow body
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 3.0, y: 4.0))
            ctx.addQuadCurve(to: CGPoint(x: 14.5, y: 14.5), control: CGPoint(x: 4.5, y: 13.5))
            ctx.strokePath()
            
            // Arrowhead
            let head = CGMutablePath()
            head.move(to: CGPoint(x: 15.5, y: 15.5))
            head.addLine(to: CGPoint(x: 9.5, y: 14.5))
            head.addLine(to: CGPoint(x: 12.0, y: 12.0))
            head.addLine(to: CGPoint(x: 14.5, y: 9.5))
            head.closeSubpath()
            ctx.addPath(head)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            ctx.restoreGState()
        }
    }
    
    static func createRectIcon() -> NSImage {
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
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 2.5, y: 2.5))
            path.addLine(to: CGPoint(x: 5.5, y: 3.0))
            path.addLine(to: CGPoint(x: 14.5, y: 12.0))
            path.addLine(to: CGPoint(x: 12.0, y: 14.5))
            path.addLine(to: CGPoint(x: 3.0, y: 5.5))
            path.closeSubpath()
            
            ctx.addPath(path)
            ctx.strokePath()
            
            // Nib point
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 2.5, y: 2.5))
            ctx.addLine(to: CGPoint(x: 4.0, y: 4.0))
            ctx.strokePath()
            
            ctx.restoreGState()
        }
    }
    
    static func createHighlighterIcon() -> NSImage {
        return createTemplateImage(size: CGSize(width: 18, height: 18)) { ctx in
            ctx.saveGState()
            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            
            // Marker body
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 4.5, y: 6.5))
            body.addLine(to: CGPoint(x: 12.0, y: 14.0))
            body.addLine(to: CGPoint(x: 15.0, y: 11.0))
            body.addLine(to: CGPoint(x: 7.5, y: 3.5))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.strokePath()
            
            // Chisel tip
            let tip = CGMutablePath()
            tip.move(to: CGPoint(x: 4.5, y: 6.5))
            tip.addLine(to: CGPoint(x: 2.0, y: 3.5))
            tip.addLine(to: CGPoint(x: 5.0, y: 2.0))
            tip.addLine(to: CGPoint(x: 7.5, y: 3.5))
            tip.closeSubpath()
            ctx.addPath(tip)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            
            ctx.restoreGState()
        }
    }
    
    static func createTextIcon() -> NSImage {
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
    
    // MARK: - Mask 2: AI Smart Redact Mask (AI-Автомаска с искрами)
    static func createAIMaskIcon() -> NSImage {
        // High-end vivid gradient icon for AI Mask
        let size = CGSize(width: 22, height: 20)
        let img = NSImage(size: size, flipped: false) { bounds in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            
            // Vivid Cyan -> Violet gradient stroke for mask
            let mask = CGMutablePath()
            mask.move(to: CGPoint(x: 2.0, y: 11.0))
            mask.addQuadCurve(to: CGPoint(x: 10.5, y: 14.5), control: CGPoint(x: 5.5, y: 15.0))
            mask.addQuadCurve(to: CGPoint(x: 17.5, y: 11.0), control: CGPoint(x: 14.5, y: 15.0))
            mask.addQuadCurve(to: CGPoint(x: 15.5, y: 5.5), control: CGPoint(x: 18.0, y: 7.5))
            mask.addQuadCurve(to: CGPoint(x: 10.5, y: 8.0), control: CGPoint(x: 13.0, y: 5.0))
            mask.addQuadCurve(to: CGPoint(x: 4.0, y: 5.5), control: CGPoint(x: 7.0, y: 5.0))
            mask.addQuadCurve(to: CGPoint(x: 2.0, y: 11.0), control: CGPoint(x: 1.5, y: 7.5))
            mask.closeSubpath()
            
            ctx.setLineWidth(1.6)
            ctx.setStrokeColor(NSColor(red: 0.10, green: 0.85, blue: 1.0, alpha: 1.0).cgColor)
            ctx.addPath(mask)
            ctx.strokePath()
            
            // Eye cutouts with glowing cyan
            ctx.setFillColor(NSColor(red: 0.10, green: 0.85, blue: 1.0, alpha: 0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: 4.5, y: 8.5, width: 3.5, height: 2.5))
            ctx.fillEllipse(in: CGRect(x: 12.0, y: 8.5, width: 3.5, height: 2.5))
            
            // Sparkle 1 (Top-right corner AI Star)
            let starCenter = CGPoint(x: 18.0, y: 15.5)
            let starPath = CGMutablePath()
            starPath.move(to: CGPoint(x: starCenter.x, y: starCenter.y + 4.0))
            starPath.addQuadCurve(to: CGPoint(x: starCenter.x + 3.5, y: starCenter.y), control: CGPoint(x: starCenter.x + 0.5, y: starCenter.y + 0.5))
            starPath.addQuadCurve(to: CGPoint(x: starCenter.x, y: starCenter.y - 4.0), control: CGPoint(x: starCenter.x + 0.5, y: starCenter.y - 0.5))
            starPath.addQuadCurve(to: CGPoint(x: starCenter.x - 3.5, y: starCenter.y), control: CGPoint(x: starCenter.x - 0.5, y: starCenter.y - 0.5))
            starPath.addQuadCurve(to: CGPoint(x: starCenter.x, y: starCenter.y + 4.0), control: CGPoint(x: starCenter.x - 0.5, y: starCenter.y + 0.5))
            starPath.closeSubpath()
            
            ctx.setFillColor(NSColor(red: 1.0, green: 0.45, blue: 0.95, alpha: 1.0).cgColor)
            ctx.addPath(starPath)
            ctx.fillPath()
            
            // AI Tiny Badge at bottom right
            let font = NSFont.systemFont(ofSize: 7.0, weight: .black)
            let attr: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(red: 0.20, green: 0.90, blue: 1.0, alpha: 1.0)
            ]
            let str = NSAttributedString(string: "AI", attributes: attr)
            str.draw(at: CGPoint(x: 13.0, y: 1.0))
            
            ctx.restoreGState()
            return true
        }
        return img
    }
    
    // MARK: - Action Button Icons (Clean vector graphics)
    static func createCopyIcon() -> NSImage {
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
