import Cocoa

final class EditorWindowController: NSWindowController, ToolbarViewDelegate, CanvasViewDelegate {
    private var toolbarView: ToolbarView!
    private var canvasView: CanvasView!
    private var localKeyMonitor: Any?
    
    var onWindowDidClose: (() -> Void)?
    
    static let toolbarHeight: CGFloat = 44.0
    static let minToolbarWidth: CGFloat = 720.0
    
    convenience init(image: NSImage, targetScreen: NSScreen? = nil) {
        let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenVisibleFrame = screen.visibleFrame
        let screenScale = screen.backingScaleFactor
        
        let maxAllowedWidth = max(600.0, screenVisibleFrame.width * 0.96)
        let maxAllowedHeight = max(400.0, (screenVisibleFrame.height - Self.toolbarHeight - 32.0) * 0.94)
        
        // 1. Calculate true logical point dimensions using the screen scale
        var imgWidth = image.size.width
        var imgHeight = image.size.height
        
        if let rep = image.representations.first, rep.pixelsWide > 0 && rep.pixelsHigh > 0 {
            imgWidth = CGFloat(rep.pixelsWide) / screenScale
            imgHeight = CGFloat(rep.pixelsHigh) / screenScale
        }
        image.size = CGSize(width: imgWidth, height: imgHeight)
        
        // 2. Compute scale: preserve 1:1 true size if it fits on screen, only scale down if larger than monitor
        let scale = min(1.0, min((maxAllowedWidth - 160.0) / max(imgWidth, 1), (maxAllowedHeight - 120.0) / max(imgHeight, 1)))
        let scaledCanvasWidth = max(50.0, round(imgWidth * scale))
        let scaledCanvasHeight = max(50.0, round(imgHeight * scale))
        
        // 3. Generous initial margins (80px left/right, 50px top/bottom) for instant drawing outside screenshot
        let marginX: CGFloat = 80.0
        let marginY: CGFloat = 50.0
        
        let contentWidth = min(screenVisibleFrame.width, max(EditorWindowController.minToolbarWidth, scaledCanvasWidth + marginX * 2))
        let contentHeight = min(screenVisibleFrame.height, scaledCanvasHeight + marginY * 2 + EditorWindowController.toolbarHeight)
        
        // 4. Center content rect squarely within screenVisibleFrame
        var contentX = screenVisibleFrame.midX - contentWidth / 2.0
        var contentY = screenVisibleFrame.midY - contentHeight / 2.0
        
        if contentX < screenVisibleFrame.minX { contentX = screenVisibleFrame.minX }
        if contentX + contentWidth > screenVisibleFrame.maxX { contentX = screenVisibleFrame.maxX - contentWidth }
        if contentY < screenVisibleFrame.minY { contentY = screenVisibleFrame.minY }
        if contentY + contentHeight > screenVisibleFrame.maxY { contentY = screenVisibleFrame.maxY - contentHeight }
        
        let initialContentRect = NSRect(
            x: contentX,
            y: contentY,
            width: contentWidth,
            height: contentHeight
        )
        
        let panel = NSPanel(
            contentRect: initialContentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        
        panel.title = "ShotSnap — Редактор"
        panel.titlebarAppearsTransparent = false
        panel.isReleasedWhenClosed = false
        
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = true
        panel.hidesOnDeactivate = false
        
        panel.level = .modalPanel
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        panel.hasShadow = true
        
        let fullFrame = panel.frameRect(forContentRect: initialContentRect)
        panel.setFrame(fullFrame, display: true)
        
        self.init(window: panel)
        
        setupViews(image: image, scaledSize: CGSize(width: scaledCanvasWidth, height: scaledCanvasHeight), contentSize: initialContentRect.size)
        setupKeyboardMonitoring()
    }
    
    private func setupViews(image: NSImage, scaledSize: CGSize, contentSize: CGSize) {
        guard let window = window, let contentView = window.contentView else { return }
        
        // 1. Toolbar View pinned to top
        toolbarView = ToolbarView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.delegate = self
        contentView.addSubview(toolbarView)
        
        // 2. Canvas View fills the entire area below the toolbar (full click surface)
        canvasView = CanvasView(frame: .zero)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.delegate = self
        contentView.addSubview(canvasView)
        
        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: Self.toolbarHeight),
            
            canvasView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // Center baseImageRect inside the initial canvas area
        let canvasW = contentSize.width
        let canvasH = contentSize.height - Self.toolbarHeight
        let originX = round((canvasW - scaledSize.width) / 2.0)
        let originY = round((canvasH - scaledSize.height) / 2.0)
        let initialBaseRect = CGRect(x: originX, y: originY, width: scaledSize.width, height: scaledSize.height)
        
        canvasView.setBaseImage(image, initialRect: initialBaseRect)
        
        let savedSizeIdx = max(0, min(toolbarView.sizePresets.count - 1, PreferencesManager.shared.savedSizeIndex))
        let preset = toolbarView.sizePresets[savedSizeIdx]
        canvasView.applySizePreset(lineWidth: preset.lineWidth, stepRadius: preset.stepRadius, fontSize: preset.fontSize)
    }
    
    private func setupKeyboardMonitoring() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else { return event }
            
            let isCmd = event.modifierFlags.contains(.command)
            let isShift = event.modifierFlags.contains(.shift)
            let isOption = event.modifierFlags.contains(.option)
            
            if isCmd {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    if isShift || isOption {
                        self.toolbarDidClickCLIPath()
                    } else {
                        self.performCopy()
                    }
                    return nil
                case "v":
                    if !(self.window?.firstResponder is NSText) {
                        self.performPasteFromClipboard()
                        return nil
                    }
                case "b":
                    self.toolbarDidClickBase64()
                    return nil
                case "o":
                    self.toolbarDidClickOCR()
                    return nil
                case "s":
                    self.performSave()
                    return nil
                case "z":
                    if isShift {
                        self.canvasView.redo()
                    } else {
                        self.canvasView.undo()
                    }
                    return nil
                default:
                    break
                }
            } else {
                // Standalone keys
                if event.keyCode == 36 { // Return / Enter
                    if let textAnn = self.canvasView.selectedAnnotation as? TextAnnotation, !(self.window?.firstResponder is NSText) {
                        self.canvasView.showTextEditor(for: textAnn)
                        return nil
                    }
                    self.performCopy()
                    return nil
                } else if event.keyCode == 53 { // Escape
                    self.close()
                    return nil
                } else if event.keyCode == 51 || event.keyCode == 117 { // Backspace / Delete
                    if !(self.window?.firstResponder is NSText) {
                        self.canvasView.deleteSelected()
                        return nil
                    }
                }
                
                // Tool shortcut letters (if not focused in text)
                if !(self.window?.firstResponder is NSText) {
                    if let char = event.charactersIgnoringModifiers?.uppercased() {
                        for tool in ToolType.allCases {
                            if tool.shortcutKey == char {
                                self.toolbarView.selectTool(tool)
                                self.canvasView.currentTool = tool
                                return nil
                            }
                        }
                    }
                }
            }
            
            return event
        }
    }
    
    // MARK: - Bulletproof Clipboard Image Extraction
    static func extractImageFromPasteboard(_ pb: NSPasteboard) -> NSImage? {
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let first = images.first {
            return first
        }
        if let img = NSImage(pasteboard: pb) {
            return img
        }
        let supportedTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("image/png"),
            NSPasteboard.PasteboardType("image/jpeg")
        ]
        for t in supportedTypes {
            if let data = pb.data(forType: t), let img = NSImage(data: data) {
                return img
            }
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let img = NSImage(contentsOf: url) {
                    return img
                }
            }
        }
        return nil
    }
    
    private func performPasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        if let image = Self.extractImageFromPasteboard(pasteboard) {
            canvasView.pasteImage(image)
            logSnap("🖼 Изображение успешно вставлено из буфера обмена!")
            return
        }
        
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            canvasView.pasteText(str)
            logSnap("📝 Текст успешно вставлен из буфера обмена!")
            return
        }
        
        NSSound(named: "Basso")?.play()
        logSnap("⚠️ В буфере обмена нет изображения или текста для вставки")
    }
    
    // MARK: - Canvas Delegate & Window Auto-Expansion
    func canvasDidChangeSize(_ canvas: CanvasView, newSize: CGSize) {
        guard let window = window else { return }
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        let maxAllowedWidth = screenFrame.width * 0.96
        let maxAllowedHeight = (screenFrame.height - Self.toolbarHeight - 32.0) * 0.94
        
        let targetContentWidth = min(maxAllowedWidth, max(Self.minToolbarWidth, newSize.width))
        let targetContentHeight = min(maxAllowedHeight, newSize.height + Self.toolbarHeight)
        
        let currentContentRect = window.contentRect(forFrameRect: window.frame)
        let deltaW = targetContentWidth - currentContentRect.width
        let deltaH = targetContentHeight - currentContentRect.height
        
        if deltaW > 1.0 || deltaH > 1.0 {
            let newX = max(screenFrame.minX, min(screenFrame.maxX - targetContentWidth, currentContentRect.minX - deltaW / 2.0))
            let newY = max(screenFrame.minY, min(screenFrame.maxY - targetContentHeight, currentContentRect.minY - deltaH / 2.0))
            let newContentRect = NSRect(x: newX, y: newY, width: targetContentWidth, height: targetContentHeight)
            let newWindowFrame = window.frameRect(forContentRect: newContentRect)
            window.setFrame(newWindowFrame, display: true, animate: true)
        }
    }
    
    // MARK: - Toolbar Actions
    func toolbarDidSelectTool(_ tool: ToolType) {
        canvasView.currentTool = tool
    }
    
    func toolbarDidSelectColor(_ color: NSColor) {
        canvasView.currentColor = color
    }
    
    func toolbarDidSelectSizePreset(lineWidth: CGFloat, stepRadius: CGFloat, fontSize: CGFloat) {
        canvasView.applySizePreset(lineWidth: lineWidth, stepRadius: stepRadius, fontSize: fontSize)
    }
    
    func toolbarDidClickUndo() {
        canvasView.undo()
    }
    
    func toolbarDidClickPaste() {
        performPasteFromClipboard()
    }
    
    func toolbarDidClickCopy() {
        performCopy()
    }
    
    func toolbarDidClickBase64() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else { return }
        
        let result = ImageRenderer.render(
            baseImage: base,
            baseImageRect: canvasView.baseImageRect,
            exportRect: canvasView.calculateExportRect(),
            annotations: canvasView.annotations,
            viewBounds: canvasView.bounds
        )
        
        ImageRenderer.copyBase64ToClipboard(pngData: result.pngData)
        logSnap("⚡️ Изображение скопировано в буфер обмена как Base64!")
        close()
    }
    
    func toolbarDidClickOCR() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else { return }
        
        let result = ImageRenderer.render(
            baseImage: base,
            baseImageRect: canvasView.baseImageRect,
            exportRect: canvasView.calculateExportRect(),
            annotations: canvasView.annotations,
            viewBounds: canvasView.bounds
        )
        
        OCRManager.shared.recognizeText(from: result.image) { [weak self] text in
            guard let self = self else { return }
            if let text = text, !text.isEmpty {
                ImageRenderer.copyTextToClipboard(text)
                logSnap("📝 Текст успешно распознан и скопирован в буфер (\(text.count) символов)")
                self.close()
            } else {
                let alert = NSAlert()
                alert.messageText = "Текст не найден"
                alert.informativeText = "На снимке не удалось распознать печатный текст."
                alert.runModal()
            }
        }
    }
    
    func toolbarDidClickCLIPath() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else {
            close()
            return
        }
        
        let result = ImageRenderer.render(
            baseImage: base,
            baseImageRect: canvasView.baseImageRect,
            exportRect: canvasView.calculateExportRect(),
            annotations: canvasView.annotations,
            viewBounds: canvasView.bounds
        )
        
        if let savedPath = ImageRenderer.saveToDownloadsAndCopyPath(pngData: result.pngData) {
            logSnap("📎 Файл успешно сохранен в Загрузки: \(savedPath). Путь скопирован в буфер!")
        } else {
            ImageRenderer.copyFilePathToClipboard()
            logSnap("📎 Путь файла \(ImageRenderer.persistentPath) скопирован в буфер для CLI!")
        }
        close()
    }
    
    func toolbarDidClickSave() {
        performSave()
    }
    
    func canvasDidUpdateAnnotations(_ canvas: CanvasView) {
        // Updated
    }
    
    func canvasDidSelectAnnotation(_ annotation: BaseAnnotation?) {
        if let ann = annotation {
            toolbarView.selectColor(ann.color)
        }
    }
    
    // MARK: - Execution Actions
    private func performCopy() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else {
            close()
            return
        }
        
        let result = ImageRenderer.render(
            baseImage: base,
            baseImageRect: canvasView.baseImageRect,
            exportRect: canvasView.calculateExportRect(),
            annotations: canvasView.annotations,
            viewBounds: canvasView.bounds
        )
        
        ImageRenderer.copyToClipboard(image: result.image, pngData: result.pngData)
        close()
    }
    
    private func performSave() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else { return }
        
        let result = ImageRenderer.render(
            baseImage: base,
            baseImageRect: canvasView.baseImageRect,
            exportRect: canvasView.calculateExportRect(),
            annotations: canvasView.annotations,
            viewBounds: canvasView.bounds
        )
        
        guard let pngData = result.pngData else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "Screenshot_\(Int(Date().timeIntervalSince1970)).png"
        
        savePanel.beginSheetModal(for: window!) { response in
            if response == .OK, let url = savePanel.url {
                try? pngData.write(to: url)
                self.close()
            }
        }
    }
    
    override func close() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        super.close()
        onWindowDidClose?()
    }
}
