import Cocoa

final class EditorWindowController: NSWindowController, ToolbarViewDelegate, CanvasViewDelegate {
    private var canvasView: CanvasView!
    private var toolbarView: ToolbarView!
    private var localKeyMonitor: Any?
    var onWindowDidClose: (() -> Void)?
    
    static let toolbarHeight: CGFloat = 46.0
    static let minToolbarWidth: CGFloat = 720.0
    
    convenience init(image: NSImage, targetScreen: NSScreen? = nil) {
        // 1. Identify the fresh active screen
        let currentScreens = NSScreen.screens
        let mousePos = NSEvent.mouseLocation
        
        let screen: NSScreen
        if let target = targetScreen, currentScreens.contains(where: { $0.frame == target.frame }) {
            screen = target
        } else if let mouseScreen = currentScreens.first(where: { NSMouseInRect(mousePos, $0.frame, false) }) {
            screen = mouseScreen
        } else {
            screen = NSScreen.main ?? currentScreens.first ?? NSScreen()
        }
        
        let screenScale = screen.backingScaleFactor
        let screenVisibleFrame = screen.visibleFrame
        
        logSnap("🖥 Активный экран [\(currentScreens.count) подкл.]: frame=\(screen.frame), visibleFrame=\(screenVisibleFrame), mousePos=\(mousePos), scale=\(screenScale)")
        
        let maxAllowedWidth = max(500.0, screenVisibleFrame.width * 0.94)
        let maxAllowedHeight = max(350.0, (screenVisibleFrame.height - Self.toolbarHeight - 32.0) * 0.90)
        
        // 2. Calculate true logical point dimensions using the screen scale
        var imgWidth = image.size.width
        var imgHeight = image.size.height
        
        if let rep = image.representations.first, rep.pixelsWide > 0 && rep.pixelsHigh > 0 {
            imgWidth = CGFloat(rep.pixelsWide) / screenScale
            imgHeight = CGFloat(rep.pixelsHigh) / screenScale
        }
        image.size = CGSize(width: imgWidth, height: imgHeight)
        
        // 3. Compute scale: preserve 1:1 true size if it fits on screen, only scale down if larger than monitor
        let scale = min(1.0, min(maxAllowedWidth / max(imgWidth, 1), maxAllowedHeight / max(imgHeight, 1)))
        let scaledCanvasWidth = max(50.0, round(imgWidth * scale))
        let scaledCanvasHeight = max(50.0, round(imgHeight * scale))
        
        let contentWidth = min(screenVisibleFrame.width, max(EditorWindowController.minToolbarWidth, scaledCanvasWidth))
        let contentHeight = min(screenVisibleFrame.height, scaledCanvasHeight + EditorWindowController.toolbarHeight)
        
        // 4. Center content rect squarely within screenVisibleFrame
        var contentX = screenVisibleFrame.midX - contentWidth / 2.0
        var contentY = screenVisibleFrame.midY - contentHeight / 2.0
        
        // Safe bounding
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
        
        // Use NSPanel designed for non-disruptive overlays over Full Screen spaces
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
        
        // Modal panel level guarantees presentation over full-screen apps and spaces
        panel.level = .modalPanel
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.backgroundColor = NSColor(white: 0.12, alpha: 1.0)
        panel.hasShadow = true
        
        // Calculate proper full frame including title bar
        let fullFrame = panel.frameRect(forContentRect: initialContentRect)
        panel.setFrame(fullFrame, display: true)
        
        self.init(window: panel)
        
        setupViews(image: image, canvasSize: CGSize(width: scaledCanvasWidth, height: scaledCanvasHeight))
        setupKeyboardMonitoring()
    }
    
    private func setupViews(image: NSImage, canvasSize: CGSize) {
        guard let window = window, let contentView = window.contentView else { return }
        
        // 1. Toolbar View at the very top (full window width)
        toolbarView = ToolbarView()
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.delegate = self
        contentView.addSubview(toolbarView)
        
        // 2. Container for Canvas (strictly fills space below toolbar)
        let canvasContainer = NSView()
        canvasContainer.translatesAutoresizingMaskIntoConstraints = false
        canvasContainer.wantsLayer = true
        canvasContainer.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor
        canvasContainer.layer?.masksToBounds = true
        contentView.addSubview(canvasContainer)
        
        // 3. Canvas View with EXACT aspect ratio and dimensions
        canvasView = CanvasView(frame: NSRect(origin: .zero, size: canvasSize))
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.baseImage = image
        canvasView.delegate = self
        
        let savedSizeIdx = max(0, min(toolbarView.sizePresets.count - 1, PreferencesManager.shared.savedSizeIndex))
        let preset = toolbarView.sizePresets[savedSizeIdx]
        canvasView.applySizePreset(lineWidth: preset.lineWidth, stepRadius: preset.stepRadius, fontSize: preset.fontSize)
        
        canvasContainer.addSubview(canvasView)
        
        NSLayoutConstraint.activate([
            // Toolbar layout (pinned to top of content view)
            toolbarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: Self.toolbarHeight),
            
            // Canvas container layout (starts strictly BELOW toolbar)
            canvasContainer.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            canvasContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            canvasContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            canvasContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Canvas view centered in container with exact size
            canvasView.centerXAnchor.constraint(equalTo: canvasContainer.centerXAnchor),
            canvasView.centerYAnchor.constraint(equalTo: canvasContainer.centerYAnchor),
            canvasView.widthAnchor.constraint(equalToConstant: canvasSize.width),
            canvasView.heightAnchor.constraint(equalToConstant: canvasSize.height)
        ])
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
    
    func toolbarDidClickCopy() {
        performCopy()
    }
    
    func toolbarDidClickBase64() {
        canvasView.commitActiveTextField()
        guard let base = canvasView.baseImage else { return }
        
        let result = ImageRenderer.render(
            baseImage: base,
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
