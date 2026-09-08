import Cocoa
import CoreGraphics

func saveImage(_ image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG for \(url.path)")
    }
    try! pngData.write(to: url)
}

func createDMGBackground660x440() -> NSImage {
    let size = CGSize(width: 660, height: 440)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // Background Dark Obsidian Gradient
    let bgColors = [
        CGColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0), // Top: #141a26
        CGColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)  // Bottom: #0a0d14
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 330, y: 440),
                               end: CGPoint(x: 330, y: 0),
                               options: [])
    }
    
    // Icon centers in Cocoa coordinates (Finder y=180 from top -> 440 - 180 = 260 from bottom)
    let leftCenter = CGPoint(x: 180, y: 250)
    let rightCenter = CGPoint(x: 480, y: 250)
    
    // Radial glow accents behind icons
    let glowColorsCyan = [
        CGColor(red: 0.0, green: 0.65, blue: 1.0, alpha: 0.22),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let g = CGGradient(colorsSpace: colorSpace, colors: glowColorsCyan, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g, startCenter: leftCenter, startRadius: 0, endCenter: leftCenter, endRadius: 130, options: [])
        ctx.drawRadialGradient(g, startCenter: rightCenter, startRadius: 0, endCenter: rightCenter, endRadius: 130, options: [])
    }
    
    // Floating Dock Pedestals under the icons (136x136, matching 128x128 icons)
    let dockSize: CGFloat = 136
    let cornerR: CGFloat = 28
    
    for centerPt in [leftCenter, rightCenter] {
        let rect = CGRect(x: centerPt.x - dockSize / 2, y: centerPt.y - dockSize / 2 - 10, width: dockSize, height: dockSize)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
        
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 0.45))
        ctx.fillPath()
        
        ctx.setStrokeColor(CGColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 0.3))
        ctx.setLineWidth(1.5)
        let dashes: [CGFloat] = [5, 4]
        ctx.setLineDash(phase: 0, lengths: dashes)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // Draw macOS Applications Folder Icon on the right pedestal
    let iconPath = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns"
    if let folderIcon = NSImage(contentsOfFile: iconPath) {
        let folderRect = CGRect(x: rightCenter.x - 56, y: rightCenter.y - 56, width: 112, height: 112)
        folderIcon.draw(in: folderRect, from: .zero, operation: .sourceOver, fraction: 0.95)
    }
    
    // Stylized Glowing Gradient Arrow between icons: from x: 275 to x: 385, y: 240
    ctx.saveGState()
    let arrowStartY: CGFloat = 240
    let arrowStart = CGPoint(x: 275, y: arrowStartY)
    let arrowEnd = CGPoint(x: 375, y: arrowStartY)
    
    ctx.setShadow(offset: .zero, blur: 16, color: CGColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.7))
    
    let arrowLine = CGMutablePath()
    arrowLine.move(to: arrowStart)
    arrowLine.addLine(to: arrowEnd)
    
    ctx.setStrokeColor(CGColor(red: 0.22, green: 0.75, blue: 1.0, alpha: 0.9))
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    ctx.addPath(arrowLine)
    ctx.strokePath()
    
    // Arrow Head
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 395, y: arrowStartY))
    head.addLine(to: CGPoint(x: 370, y: arrowStartY + 15))
    head.addLine(to: CGPoint(x: 375, y: arrowStartY))
    head.addLine(to: CGPoint(x: 370, y: arrowStartY - 15))
    head.closeSubpath()
    
    ctx.setFillColor(CGColor(red: 0.22, green: 0.75, blue: 1.0, alpha: 1.0))
    ctx.addPath(head)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Title Branding at Top
    let titleFont = NSFont.systemFont(ofSize: 26, weight: .heavy)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white
    ]
    let titleStr = NSAttributedString(string: "ShotSnap", attributes: titleAttrs)
    let titleSize = titleStr.size()
    titleStr.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 388))
    
    // Subtitle
    let subFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(white: 0.65, alpha: 1.0)
    ]
    let subStr = NSAttributedString(string: "Нативный AI-скриншотер для macOS · KULESH.PRO", attributes: subAttrs)
    let subSize = subStr.size()
    subStr.draw(at: CGPoint(x: (size.width - subSize.width) / 2, y: 364))
    
    // Bottom Drag Instruction Pill
    let pillWidth: CGFloat = 530
    let pillHeight: CGFloat = 36
    let pillRect = CGRect(x: (size.width - pillWidth) / 2, y: 56, width: pillWidth, height: pillHeight)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(pillPath)
    ctx.setFillColor(CGColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 0.85))
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 0.4))
    ctx.setLineWidth(1.5)
    ctx.addPath(pillPath)
    ctx.strokePath()
    
    let instrFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let instrAttrs: [NSAttributedString.Key: Any] = [
        .font: instrFont,
        .foregroundColor: NSColor(white: 0.92, alpha: 1.0)
    ]
    let instrStr = NSAttributedString(string: "Перетащите в «Программы» или дважды кликните для автоустановки", attributes: instrAttrs)
    let instrSize = instrStr.size()
    instrStr.draw(at: CGPoint(x: (size.width - instrSize.width) / 2, y: 56 + (pillHeight - instrSize.height) / 2))
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

let fm = FileManager.default
let currentDir = URL(fileURLWithPath: fm.currentDirectoryPath)
let resourcesDir = currentDir.appendingPathComponent("Sources/Resources")
let dmgBg = createDMGBackground660x440()
let dmgBgOutput = resourcesDir.appendingPathComponent("dmg_background.png")
saveImage(dmgBg, to: dmgBgOutput)
print("✅ dmg_background.png (660x440) успешно сохранен: \(dmgBgOutput.path)")
