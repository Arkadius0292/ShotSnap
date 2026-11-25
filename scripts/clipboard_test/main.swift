import Cocoa

// Регрессионный тест: «Копировать» кладёт на NSPasteboard данные изображения (PNG + TIFF)
// и НЕ кладёт public.file-url на временный файл (иначе Paste на другом Mac вставляет путь /tmp/...).
func check(_ ok: Bool, _ msg: String) {
    print((ok ? "PASS " : "FAIL ") + msg)
    if !ok { exit(1) }
}

let size = NSSize(width: 40, height: 30)
let image = NSImage(size: size)
image.lockFocus()
NSColor.systemBlue.setFill()
NSRect(origin: .zero, size: size).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])

ImageRenderer.copyToClipboard(image: image, pngData: png)

let pb = NSPasteboard.general
let types = (pb.types ?? []).map { $0.rawValue }
print("types: \(types)")
check(types.contains("public.png"), "public.png есть")
check(types.contains("public.tiff"), "public.tiff есть")
check(!types.contains("public.file-url"), "public.file-url отсутствует")
check(pb.string(forType: .string) == nil, "текстового представления (пути) нет")
check(pb.data(forType: .png) == png, "PNG-данные совпадают")
check(NSImage(pasteboard: pb) != nil, "NSImage(pasteboard:) читает картинку")
print("ALL PASS")
