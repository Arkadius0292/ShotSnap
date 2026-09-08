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

let sourcePath = "/Users/KuleshAV/.gemini/antigravity/brain/6812c70e-47cb-46b3-a730-8b3be91ed2a8/shotsnap_app_icon_1788861390022.jpg"
guard let rawImage = NSImage(contentsOfFile: sourcePath),
      let cgRaw = rawImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Cannot load source image from \(sourcePath)")
}

print("📷 1. Загружено утвержденное изображение иконки (Вариант 1)...")

// Produce 1024x1024 masked icon with standard Apple Squircle
let masterSize = CGSize(width: 1024, height: 1024)
let masterImage = NSImage(size: masterSize)

masterImage.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("No CGContext")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.clear(CGRect(origin: .zero, size: masterSize))

let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerR: CGFloat = 185
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)

// Drop shadow behind squircle
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 36, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38))
ctx.addPath(squirclePath)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillPath()
ctx.restoreGState()

// Clip to Apple Squircle
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.clip()

// Crop source squircle region (x: 165, y: 165, w: 694, h: 694)
let cropRect = CGRect(x: 165, y: 165, width: 694, height: 694)
if let cropped = cgRaw.cropping(to: cropRect) {
    ctx.draw(cropped, in: squircleRect)
}
ctx.restoreGState()

// Subtle specular highlight on top edge of squircle
ctx.saveGState()
ctx.addPath(squirclePath)
ctx.setLineWidth(3.0)
ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45))
ctx.strokePath()
ctx.restoreGState()

masterImage.unlockFocus()

// Save Master 1024x1024 PNG
let fm = FileManager.default
let currentDir = URL(fileURLWithPath: fm.currentDirectoryPath)
let resourcesDir = currentDir.appendingPathComponent("Sources/Resources")
let iconsetDir = currentDir.appendingPathComponent("AppIcon.iconset")

try? fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true, attributes: nil)
try? fm.removeItem(at: iconsetDir)
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true, attributes: nil)

let masterPngUrl = resourcesDir.appendingPathComponent("AppIcon_1024.png")
saveImage(masterImage, to: masterPngUrl)
print("✅ Сохранена мастер-иконка: \(masterPngUrl.path)")

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

print("📐 2. Нарезка иконок под сетку разрешений macOS...")
for (filename, pxSize) in iconSizes {
    let resized = resizeImage(masterImage, to: CGSize(width: pxSize, height: pxSize))
    let outUrl = iconsetDir.appendingPathComponent(filename)
    saveImage(resized, to: outUrl)
}

print("⚙️ 3. Компиляция AppIcon.icns через iconutil...")
let icnsOutput = resourcesDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsOutput.path]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("🎉 AppIcon.icns успешно скомпилирован: \(icnsOutput.path)")
    try? fm.removeItem(at: iconsetDir)
} else {
    fatalError("iconutil завершился с ошибкой: \(process.terminationStatus)")
}
