import Cocoa
import CoreGraphics

// MARK: - Helper Functions
func saveImage(_ image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG for \(url.path)")
    }
    try! pngData.write(to: url)
}

func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
    let resized = NSImage(size: targetSize)
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: CGRect(origin: .zero, size: targetSize),
               from: CGRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    resized.unlockFocus()
    return resized
}

// MARK: - 1. Generate 1024x1024 Master AppIcon
func createMasterAppIcon() -> NSImage {
    let size = CGSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("No graphics context")
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    // Apple Squircle Dimensions (at 1024x1024: standard icon rect is 824x824 inset by 100, corner radius ~185)
    let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // Shadow under icon squircle
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -28), blur: 48, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()
    
    // Clip to Squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    // Background Gradient: Deep Slate to Midnight Sapphire
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.15, green: 0.18, blue: 0.28, alpha: 1.0), // Top: #262e47
        CGColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1.0), // Mid: #121729
        CGColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1.0)  // Bottom: #080a14
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.5, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient,
                               start: CGPoint(x: 512, y: 924),
                               end: CGPoint(x: 512, y: 100),
                               options: [])
    }
    
    // Soft radial glow from center
    let glowColors = [
        CGColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 0.35),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGradient,
                               startCenter: CGPoint(x: 512, y: 530), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 530), endRadius: 420,
                               options: [])
    }
    
    // Grid pattern / Viewfinder lines in background (Screen Capture aesthetic)
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.08))
    ctx.setLineWidth(2.0)
    for x in stride(from: 180, through: 844, by: 80) {
        ctx.strokeLineSegments(between: [CGPoint(x: CGFloat(x), y: 100), CGPoint(x: CGFloat(x), y: 924)])
    }
    for y in stride(from: 180, through: 844, by: 80) {
        ctx.strokeLineSegments(between: [CGPoint(x: 100, y: CGFloat(y)), CGPoint(x: 924, y: CGFloat(y))])
    }
    ctx.restoreGState()
    
    // Outer Shutter / Lens Ring
    let center = CGPoint(x: 512, y: 520)
    let outerRadius: CGFloat = 240
    let ringRect = CGRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2)
    
    // Lens Ring Drop Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
    ctx.addEllipse(in: ringRect)
    ctx.setFillColor(CGColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()
    
    // Metallic Ring Gradient Border
    ctx.saveGState()
    let ringBorderWidth: CGFloat = 16
    let ringColors = [
        CGColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 1.0),
        CGColor(red: 0.12, green: 0.15, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0),
        CGColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1.0)
    ] as CFArray
    if let ringGradient = CGGradient(colorsSpace: colorSpace, colors: ringColors, locations: [0.0, 0.35, 0.7, 1.0]) {
        ctx.addEllipse(in: ringRect)
        ctx.setLineWidth(ringBorderWidth)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(ringGradient,
                               start: CGPoint(x: center.x, y: center.y + outerRadius),
                               end: CGPoint(x: center.x, y: center.y - outerRadius),
                               options: [])
    }
    ctx.restoreGState()
    
    // Deep Sapphire Glass Lens Interior
    let innerRadius: CGFloat = outerRadius - ringBorderWidth
    let innerRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
    ctx.saveGState()
    ctx.addEllipse(in: innerRect)
    ctx.clip()
    
    let lensColors = [
        CGColor(red: 0.05, green: 0.25, blue: 0.65, alpha: 1.0), // Top sapphire: #0d40a6
        CGColor(red: 0.02, green: 0.10, blue: 0.30, alpha: 1.0), // Deep blue: #051a4d
        CGColor(red: 0.01, green: 0.03, blue: 0.12, alpha: 1.0)  // Dark core
    ] as CFArray
    if let lensGradient = CGGradient(colorsSpace: colorSpace, colors: lensColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(lensGradient,
                               startCenter: CGPoint(x: center.x - 40, y: center.y + 60), startRadius: 10,
                               endCenter: center, endRadius: innerRadius,
                               options: [])
    }
    
    // Cyan Neon Iris Ring
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.8))
    ctx.setLineWidth(4.0)
    ctx.strokeEllipse(in: CGRect(x: center.x - 120, y: center.y - 120, width: 240, height: 240))
    
    // Magenta AI Neon Arc inside lens
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.18, blue: 0.60, alpha: 0.75))
    ctx.setLineWidth(5.0)
    ctx.addArc(center: center, radius: 140, startAngle: 0.2 * .pi, endAngle: 0.85 * .pi, clockwise: false)
    ctx.strokePath()
    
    // Diagonal Lens Flare Highlight
    let flarePath = CGMutablePath()
    flarePath.addEllipse(in: CGRect(x: center.x - 150, y: center.y + 40, width: 300, height: 110))
    ctx.saveGState()
    ctx.rotate(by: 0.4)
    ctx.addPath(flarePath)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.16))
    ctx.fillPath()
    ctx.restoreGState()
    
    ctx.restoreGState() // end lens clip
    
    // Viewfinder Reticle Brackets (4 corners around the lens)
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.22, green: 0.85, blue: 1.0, alpha: 0.95))
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    
    let bDist: CGFloat = 310
    let bLen: CGFloat = 52
    
    // Top-Left Reticle
    ctx.beginPath()
    ctx.move(to: CGPoint(x: center.x - bDist, y: center.y + bDist - bLen))
    ctx.addLine(to: CGPoint(x: center.x - bDist, y: center.y + bDist))
    ctx.addLine(to: CGPoint(x: center.x - bDist + bLen, y: center.y + bDist))
    ctx.strokePath()
    
    // Top-Right Reticle
    ctx.beginPath()
    ctx.move(to: CGPoint(x: center.x + bDist - bLen, y: center.y + bDist))
    ctx.addLine(to: CGPoint(x: center.x + bDist, y: center.y + bDist))
    ctx.addLine(to: CGPoint(x: center.x + bDist, y: center.y + bDist - bLen))
    ctx.strokePath()
    
    // Bottom-Left Reticle
    ctx.beginPath()
    ctx.move(to: CGPoint(x: center.x - bDist, y: center.y - bDist + bLen))
    ctx.addLine(to: CGPoint(x: center.x - bDist, y: center.y - bDist))
    ctx.addLine(to: CGPoint(x: center.x - bDist + bLen, y: center.y - bDist))
    ctx.strokePath()
    
    // Bottom-Right Reticle
    ctx.beginPath()
    ctx.move(to: CGPoint(x: center.x + bDist - bLen, y: center.y - bDist))
    ctx.addLine(to: CGPoint(x: center.x + bDist, y: center.y - bDist))
    ctx.addLine(to: CGPoint(x: center.x + bDist, y: center.y - bDist + bLen))
    ctx.strokePath()
    ctx.restoreGState()
    
    // Dynamic Bezier Arrow cutting across bottom-left to top-right
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: CGColor(red: 1.0, green: 0.18, blue: 0.58, alpha: 0.6))
    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: center.x - 220, y: center.y - 180))
    arrowPath.addCurve(to: CGPoint(x: center.x + 190, y: center.y + 170),
                       control1: CGPoint(x: center.x - 80, y: center.y - 200),
                       control2: CGPoint(x: center.x + 120, y: center.y - 60))
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.22, blue: 0.62, alpha: 0.95))
    ctx.setLineWidth(16)
    ctx.setLineCap(.round)
    ctx.addPath(arrowPath)
    ctx.strokePath()
    
    // Arrow Head at top right
    let head = CGMutablePath()
    head.move(to: CGPoint(x: center.x + 215, y: center.y + 200))
    head.addLine(to: CGPoint(x: center.x + 155, y: center.y + 195))
    head.addLine(to: CGPoint(x: center.x + 180, y: center.y + 140))
    head.closeSubpath()
    ctx.setFillColor(CGColor(red: 1.0, green: 0.22, blue: 0.62, alpha: 1.0))
    ctx.addPath(head)
    ctx.fillPath()
    ctx.restoreGState()
    
    // AI Pill Badge at bottom right: "AI"
    let aiBadgeRect = CGRect(x: 580, y: 180, width: 190, height: 96)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
    let aiBadgePath = CGPath(roundedRect: aiBadgeRect, cornerWidth: 32, cornerHeight: 32, transform: nil)
    ctx.addPath(aiBadgePath)
    ctx.setFillColor(CGColor(red: 0.95, green: 0.15, blue: 0.55, alpha: 0.95))
    ctx.fillPath()
    
    // Border around AI pill
    ctx.setStrokeColor(CGColor(red: 1.0, green: 0.6, blue: 0.85, alpha: 0.8))
    ctx.setLineWidth(3.0)
    ctx.addPath(aiBadgePath)
    ctx.strokePath()
    
    // AI Text
    let font = NSFont.systemFont(ofSize: 56, weight: .black)
    let aiAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let aiString = NSAttributedString(string: "AI", attributes: aiAttrs)
    let strSize = aiString.size()
    let strOrigin = CGPoint(x: aiBadgeRect.midX - strSize.width / 2, y: aiBadgeRect.midY - strSize.height / 2 - 2)
    aiString.draw(at: strOrigin)
    ctx.restoreGState()
    
    // Squircle Bevel Highlight (Rim light on top edge)
    ctx.saveGState()
    let rimPath = squirclePath
    ctx.addPath(rimPath)
    ctx.setLineWidth(4.0)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25))
    ctx.strokePath()
    ctx.restoreGState()
    
    ctx.restoreGState() // end squircle clip
    
    image.unlockFocus()
    return image
}

// MARK: - 2. Generate DMG Background (1320 x 800 px for 660 x 400 pt Retina)
func createDMGBackground() -> NSImage {
    let size = CGSize(width: 1320, height: 800)
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
                               start: CGPoint(x: 660, y: 800),
                               end: CGPoint(x: 660, y: 0),
                               options: [])
    }
    
    // Subtle radial glow accents behind icons
    // Icon 1 at x: 180 pt -> 360 px, y: 190 pt from top -> y: 800 - 380 = 420 px
    // Icon 2 at x: 480 pt -> 960 px, y: 190 pt from top -> y: 420 px
    let leftGlowCenter = CGPoint(x: 360, y: 420)
    let rightGlowCenter = CGPoint(x: 960, y: 420)
    
    let glowColorsCyan = [
        CGColor(red: 0.0, green: 0.65, blue: 1.0, alpha: 0.18),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    if let g = CGGradient(colorsSpace: colorSpace, colors: glowColorsCyan, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(g, startCenter: leftGlowCenter, startRadius: 0, endCenter: leftGlowCenter, endRadius: 220, options: [])
        ctx.drawRadialGradient(g, startCenter: rightGlowCenter, startRadius: 0, endCenter: rightGlowCenter, endRadius: 220, options: [])
    }
    
    // Floating Dock Pedestals under the icons
    let dockWidth: CGFloat = 220
    let dockHeight: CGFloat = 220
    let cornerR: CGFloat = 48
    
    for centerPt in [leftGlowCenter, rightGlowCenter] {
        let rect = CGRect(x: centerPt.x - dockWidth / 2, y: centerPt.y - dockHeight / 2 - 20, width: dockWidth, height: dockHeight)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
        
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 0.45))
        ctx.fillPath()
        
        ctx.setStrokeColor(CGColor(red: 0.35, green: 0.45, blue: 0.65, alpha: 0.25))
        ctx.setLineWidth(2.0)
        let dashes: [CGFloat] = [8, 6]
        ctx.setLineDash(phase: 0, lengths: dashes)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // Stylized Glowing Gradient Arrow between icons: from x: 520 px to x: 800 px, y: 400 px
    ctx.saveGState()
    let arrowStartY: CGFloat = 400
    let arrowStart = CGPoint(x: 520, y: arrowStartY)
    let arrowEnd = CGPoint(x: 770, y: arrowStartY)
    
    // Arrow Glow
    ctx.setShadow(offset: .zero, blur: 24, color: CGColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 0.65))
    
    let arrowLine = CGMutablePath()
    arrowLine.move(to: arrowStart)
    arrowLine.addLine(to: CGPoint(x: 750, y: arrowStartY))
    
    ctx.setStrokeColor(CGColor(red: 0.22, green: 0.75, blue: 1.0, alpha: 0.85))
    ctx.setLineWidth(10)
    ctx.setLineCap(.round)
    ctx.addPath(arrowLine)
    ctx.strokePath()
    
    // Arrow Head
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 795, y: arrowStartY))
    head.addLine(to: CGPoint(x: 745, y: arrowStartY + 28))
    head.addLine(to: CGPoint(x: 755, y: arrowStartY))
    head.addLine(to: CGPoint(x: 745, y: arrowStartY - 28))
    head.closeSubpath()
    
    ctx.setFillColor(CGColor(red: 0.22, green: 0.75, blue: 1.0, alpha: 0.95))
    ctx.addPath(head)
    ctx.fillPath()
    ctx.restoreGState()
    
    // Title Branding at Top
    let titleFont = NSFont.systemFont(ofSize: 42, weight: .heavy)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white
    ]
    let titleStr = NSAttributedString(string: "ShotSnap", attributes: titleAttrs)
    let titleSize = titleStr.size()
    titleStr.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 705))
    
    // Subtitle
    let subFont = NSFont.systemFont(ofSize: 22, weight: .medium)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(white: 0.65, alpha: 1.0)
    ]
    let subStr = NSAttributedString(string: "Нативный AI-скриншотер для macOS · KULESH.PRO", attributes: subAttrs)
    let subSize = subStr.size()
    subStr.draw(at: CGPoint(x: (size.width - subSize.width) / 2, y: 668))
    
    // Bottom Drag Instruction Pill
    let pillWidth: CGFloat = 720
    let pillHeight: CGFloat = 64
    let pillRect = CGRect(x: (size.width - pillWidth) / 2, y: 80, width: pillWidth, height: pillHeight)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 32, cornerHeight: 32, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(pillPath)
    ctx.setFillColor(CGColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 0.7))
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 0.35))
    ctx.setLineWidth(2.0)
    ctx.addPath(pillPath)
    ctx.strokePath()
    
    let instrFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
    let instrAttrs: [NSAttributedString.Key: Any] = [
        .font: instrFont,
        .foregroundColor: NSColor(white: 0.92, alpha: 1.0)
    ]
    let instrStr = NSAttributedString(string: "Перетащите ShotSnap в папку «Программы» для установки", attributes: instrAttrs)
    let instrSize = instrStr.size()
    instrStr.draw(at: CGPoint(x: (size.width - instrSize.width) / 2, y: 80 + (pillHeight - instrSize.height) / 2))
    ctx.restoreGState()
    
    image.unlockFocus()
    return image
}

// MARK: - Execution
let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let resourcesDir = currentDir.appendingPathComponent("Sources/Resources")
let iconsetDir = currentDir.appendingPathComponent("AppIcon.iconset")

try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true, attributes: nil)
try? fileManager.removeItem(at: iconsetDir)
try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true, attributes: nil)

print("🎨 1. Генерация мастер-иконки 1024x1024...")
let masterIcon = createMasterAppIcon()

// Generate iconset sizes
let iconSizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, pxSize) in iconSizes {
    let resized = resizeImage(masterIcon, to: CGSize(width: pxSize, height: pxSize))
    let outUrl = iconsetDir.appendingPathComponent(filename)
    saveImage(resized, to: outUrl)
}

print("⚙️ 2. Компиляция AppIcon.icns через iconutil...")
let icnsOutput = resourcesDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsOutput.path]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✅ AppIcon.icns успешно создан: \(icnsOutput.path)")
    try? fileManager.removeItem(at: iconsetDir)
} else {
    fatalError("iconutil failed with code \(process.terminationStatus)")
}

print("🖼️ 3. Генерация фона DMG инсталлятора 1320x800...")
let dmgBg = createDMGBackground()
let dmgBgOutput = resourcesDir.appendingPathComponent("dmg_background.png")
saveImage(dmgBg, to: dmgBgOutput)
print("✅ dmg_background.png успешно создан: \(dmgBgOutput.path)")
