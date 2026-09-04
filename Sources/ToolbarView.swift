import Cocoa
import CoreText

// MARK: - Gradient Brand Label
final class GradientLabel: NSView {
    private let text: String
    private let font = NSFont.systemFont(ofSize: 12, weight: .black)
    
    init(text: String) {
        self.text = text
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: NSSize {
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        let s = attr.size()
        return NSSize(width: ceil(s.width) + 4, height: ceil(s.height) + 2)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let attrString = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white
            ]
        )
        
        let textSize = attrString.size()
        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        let line = CTLineCreateWithAttributedString(attrString)
        
        context.saveGState()
        
        // Neon Glow
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 7, color: NSColor(red: 0.1, green: 0.9, blue: 1.0, alpha: 0.8).cgColor)
        
        // Position for CoreText drawing
        context.textPosition = CGPoint(x: textRect.origin.x, y: textRect.origin.y + 2)
        
        // Clip context to glyph outlines
        context.setTextDrawingMode(.clip)
        CTLineDraw(line, context)
        
        // Vivid High-Contrast Gradient: Electric Cyan -> Sky Blue -> Violet -> Neon Pink
        let colors = [
            NSColor(red: 0.10, green: 0.95, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.30, green: 0.70, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 0.70, green: 0.40, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(red: 1.00, green: 0.40, blue: 0.90, alpha: 1.0).cgColor
        ] as CFArray
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: textRect.minX, y: textRect.midY),
                end: CGPoint(x: textRect.maxX, y: textRect.midY),
                options: []
            )
        }
        
        context.restoreGState()
    }
}

// MARK: - Brand Badge View (High-Contrast, Clickable link to kulesh.pro)
final class BrandBadgeView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        // High contrast background & border for maximum readability on gray backgrounds
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 1.2
        layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        toolTip = "Открыть сайт разработчика: https://kulesh.pro"
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        let prefixLabel = NSTextField(labelWithString: "Сделано в")
        prefixLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        prefixLabel.textColor = NSColor.white // Pure bright white for high contrast
        stack.addArrangedSubview(prefixLabel)
        
        let brand = GradientLabel(text: "KULESH.PRO")
        stack.addArrangedSubview(brand)
        
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        if bounds.contains(pt) {
            if let url = URL(string: "https://kulesh.pro") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Size Preset Structure
struct SizePreset {
    let name: String
    let symbol: String
    let lineWidth: CGFloat
    let stepRadius: CGFloat
    let fontSize: CGFloat
}

// MARK: - Toolbar View Protocol
protocol ToolbarViewDelegate: AnyObject {
    func toolbarDidSelectTool(_ tool: ToolType)
    func toolbarDidSelectColor(_ color: NSColor)
    func toolbarDidSelectSizePreset(lineWidth: CGFloat, stepRadius: CGFloat, fontSize: CGFloat)
    func toolbarDidClickUndo()
    func toolbarDidClickPaste()
    func toolbarDidClickAIMask()
    func toolbarDidClickCopy()
    func toolbarDidClickBase64()
    func toolbarDidClickOCR()
    func toolbarDidClickCLIPath()
    func toolbarDidClickSave()
}

final class ToolbarView: NSVisualEffectView {
    weak var delegate: ToolbarViewDelegate?
    
    private var toolButtons: [ToolType: NSButton] = [:]
    private var colorButtons: [(NSColor, NSButton)] = []
    private var sizeButtons: [(SizePreset, NSButton)] = []
    
    private let availableColors: [(String, NSColor)] = [
        ("Красный", NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)),
        ("Оранжевый", NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)),
        ("Желтый", NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)),
        ("Зеленый", NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)),
        ("Синий", NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)),
        ("Фиолетовый", NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)),
        ("Белый", NSColor.white),
        ("Черный", NSColor(white: 0.15, alpha: 1.0))
    ]
    
    let sizePresets: [SizePreset] = [
        SizePreset(name: "Маленький / Тонкий", symbol: "•", lineWidth: 2.5, stepRadius: 11.0, fontSize: 13.0),
        SizePreset(name: "Средний / Стандартный", symbol: "●", lineWidth: 4.5, stepRadius: 15.0, fontSize: 17.0),
        SizePreset(name: "Большой / Крупный", symbol: "⬤", lineWidth: 8.0, stepRadius: 20.0, fontSize: 24.0)
    ]
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        material = .titlebar
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        
        let bottomBorder = CALayer()
        bottomBorder.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        bottomBorder.frame = CGRect(x: 0, y: 0, width: 10000, height: 1)
        layer?.addSublayer(bottomBorder)
        
        let mainStack = NSStackView()
        mainStack.orientation = .horizontal
        mainStack.spacing = 8
        mainStack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // 1. Tool Buttons
        let toolStack = NSStackView()
        toolStack.orientation = .horizontal
        toolStack.spacing = 3
        
        for tool in ToolType.allCases {
            let btn = createIconButton(image: tool.icon, tooltip: tool.description)
            btn.target = self
            btn.action = #selector(toolButtonClicked(_:))
            toolButtons[tool] = btn
            toolStack.addArrangedSubview(btn)
        }
        mainStack.addArrangedSubview(toolStack)
        
        // Separator
        mainStack.addArrangedSubview(createSeparator())
        
        // 2. Color Palette
        let colorStack = NSStackView()
        colorStack.orientation = .horizontal
        colorStack.spacing = 4
        
        for (name, color) in availableColors {
            let btn = createColorButton(color: color, tooltip: name)
            btn.target = self
            btn.action = #selector(colorButtonClicked(_:))
            colorButtons.append((color, btn))
            colorStack.addArrangedSubview(btn)
        }
        mainStack.addArrangedSubview(colorStack)
        
        // Separator
        mainStack.addArrangedSubview(createSeparator())
        
        // 3. Unified Size Presets (Auto-scales lines, arrows, step markers, and text)
        let sizeStack = NSStackView()
        sizeStack.orientation = .horizontal
        sizeStack.spacing = 3
        
        for preset in sizePresets {
            let btn = NSButton(title: preset.symbol, target: self, action: #selector(sizeButtonClicked(_:)))
            btn.bezelStyle = .recessed
            btn.isBordered = false
            btn.font = NSFont.systemFont(ofSize: 14)
            btn.toolTip = "Масштаб: \(preset.name) (толщина линий, размер шагов и шрифта)"
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 5
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            sizeButtons.append((preset, btn))
            sizeStack.addArrangedSubview(btn)
        }
        mainStack.addArrangedSubview(sizeStack)
        
        // Separator
        mainStack.addArrangedSubview(createSeparator())
        
        // 4. Undo & Paste Buttons
        let undoBtn = createIconButton(image: IconFactory.createUndoIcon(), tooltip: "Отменить (⌘Z)")
        undoBtn.target = self
        undoBtn.action = #selector(undoClicked)
        mainStack.addArrangedSubview(undoBtn)
        
        let pasteBtn = createIconButton(image: IconFactory.createPasteIcon(), tooltip: "Вставить из буфера (⌘V)")
        pasteBtn.target = self
        pasteBtn.action = #selector(pasteClicked)
        mainStack.addArrangedSubview(pasteBtn)
        
        // Separator
        mainStack.addArrangedSubview(createSeparator())
        
        // 5. Dual Mask Option: AI Smart Mask (AI-Автомаска с локальным распознаванием)
        let aiMaskBtn = NSButton(title: "AI Маска", target: self, action: #selector(aiMaskClicked))
        aiMaskBtn.image = IconFactory.createAIMaskIcon()
        aiMaskBtn.imagePosition = .imageLeading
        aiMaskBtn.imageScaling = .scaleProportionallyDown
        aiMaskBtn.bezelStyle = .rounded
        aiMaskBtn.toolTip = "AI-Автомаска: найти и скрыть пароли, ключи, токены и ПДн (⌘D)"
        aiMaskBtn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        mainStack.addArrangedSubview(aiMaskBtn)
        
        // Separator
        mainStack.addArrangedSubview(createSeparator())
        
        // 6. Action Buttons (Copy, Base64, OCR, CLI Path, Save)
        let copyBtn = NSButton(title: "Скопировать (⏎)", target: self, action: #selector(copyClicked))
        copyBtn.image = IconFactory.createCopyIcon()
        copyBtn.imagePosition = .imageLeading
        copyBtn.imageScaling = .scaleProportionallyDown
        copyBtn.bezelStyle = .rounded
        copyBtn.wantsLayer = true
        copyBtn.attributedTitle = NSAttributedString(
            string: "Скопировать (⏎)",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold)
            ]
        )
        copyBtn.layer?.backgroundColor = NSColor(red: 0.15, green: 0.65, blue: 0.35, alpha: 1.0).cgColor
        copyBtn.layer?.cornerRadius = 6
        mainStack.addArrangedSubview(copyBtn)
        
        let b64Btn = NSButton(title: "Base64 (⌘B)", target: self, action: #selector(base64Clicked))
        b64Btn.image = IconFactory.createBase64Icon()
        b64Btn.imagePosition = .imageLeading
        b64Btn.imageScaling = .scaleProportionallyDown
        b64Btn.bezelStyle = .rounded
        b64Btn.toolTip = "Скопировать как Base64 строку (для передачи через Termius/SSH)"
        b64Btn.font = NSFont.systemFont(ofSize: 12)
        mainStack.addArrangedSubview(b64Btn)
        
        let ocrBtn = NSButton(title: "OCR (⌘O)", target: self, action: #selector(ocrClicked))
        ocrBtn.image = IconFactory.createOCRIcon()
        ocrBtn.imagePosition = .imageLeading
        ocrBtn.imageScaling = .scaleProportionallyDown
        ocrBtn.bezelStyle = .rounded
        ocrBtn.toolTip = "Распознать и скопировать текст со скриншота"
        ocrBtn.font = NSFont.systemFont(ofSize: 12)
        mainStack.addArrangedSubview(ocrBtn)
        
        let cliBtn = NSButton(title: "CLI Путь (⇧⌘C)", target: self, action: #selector(cliPathClicked))
        cliBtn.image = IconFactory.createCLIIcon()
        cliBtn.imagePosition = .imageLeading
        cliBtn.imageScaling = .scaleProportionallyDown
        cliBtn.bezelStyle = .rounded
        cliBtn.toolTip = "Сохранить файл в Загрузки и скопировать абсолютный путь в буфер"
        cliBtn.font = NSFont.systemFont(ofSize: 12)
        mainStack.addArrangedSubview(cliBtn)
        
        let saveBtn = NSButton(title: "", target: self, action: #selector(saveClicked))
        saveBtn.image = IconFactory.createSaveIcon()
        saveBtn.imagePosition = .imageOnly
        saveBtn.imageScaling = .scaleProportionallyDown
        saveBtn.bezelStyle = .rounded
        saveBtn.toolTip = "Сохранить файл в выбранное место (⌘S)"
        saveBtn.font = NSFont.systemFont(ofSize: 12)
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        saveBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        mainStack.addArrangedSubview(saveBtn)
        
        // Flexible Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainStack.addArrangedSubview(spacer)
        
        // 6. Interactive Branding Badge: Сделано в KULESH.PRO
        let brandBadge = BrandBadgeView()
        mainStack.addArrangedSubview(brandBadge)
        
        // Restore Persistent User Preferences
        let savedColorIdx = max(0, min(availableColors.count - 1, PreferencesManager.shared.savedColorIndex))
        let savedSizeIdx = max(0, min(sizePresets.count - 1, PreferencesManager.shared.savedSizeIndex))
        
        selectTool(.arrow)
        selectColor(availableColors[savedColorIdx].1)
        selectSizePreset(sizePresets[savedSizeIdx])
    }
    
    // MARK: - Helpers
    private func createIconButton(image: NSImage, tooltip: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .recessed
        btn.isBordered = false
        btn.toolTip = tooltip
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 5
        btn.image = image
        btn.imagePosition = .imageOnly
        btn.imageScaling = .scaleProportionallyDown
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return btn
    }
    
    private func createColorButton(color: NSColor, tooltip: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .inline
        btn.title = ""
        btn.isBordered = false
        btn.toolTip = tooltip
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 9
        btn.layer?.backgroundColor = color.cgColor
        btn.layer?.borderWidth = 1.5
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 18).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return btn
    }
    
    private func createSeparator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }
    
    // MARK: - Selection State
    func selectTool(_ tool: ToolType) {
        for (t, btn) in toolButtons {
            let isSelected = (t == tool)
            btn.layer?.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.25).cgColor : NSColor.clear.cgColor
            btn.layer?.borderWidth = isSelected ? 1.0 : 0.0
            btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        }
    }
    
    func selectColor(_ color: NSColor) {
        for (idx, (c, btn)) in colorButtons.enumerated() {
            let isSelected = (c == color)
            btn.layer?.borderWidth = isSelected ? 3.0 : 1.5
            btn.layer?.borderColor = isSelected ? NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.3).cgColor
            if isSelected {
                PreferencesManager.shared.savedColorIndex = idx
            }
        }
    }
    
    func selectSizePreset(_ preset: SizePreset) {
        for (idx, (p, btn)) in sizeButtons.enumerated() {
            let isSelected = (p.lineWidth == preset.lineWidth)
            btn.layer?.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.25).cgColor : NSColor.clear.cgColor
            if isSelected {
                PreferencesManager.shared.savedSizeIndex = idx
            }
        }
    }
    
    // MARK: - Actions
    @objc private func toolButtonClicked(_ sender: NSButton) {
        for (tool, btn) in toolButtons where btn == sender {
            selectTool(tool)
            delegate?.toolbarDidSelectTool(tool)
            break
        }
    }
    
    @objc private func colorButtonClicked(_ sender: NSButton) {
        for (color, btn) in colorButtons where btn == sender {
            selectColor(color)
            delegate?.toolbarDidSelectColor(color)
            break
        }
    }
    
    @objc private func sizeButtonClicked(_ sender: NSButton) {
        for (preset, btn) in sizeButtons where btn == sender {
            selectSizePreset(preset)
            delegate?.toolbarDidSelectSizePreset(
                lineWidth: preset.lineWidth,
                stepRadius: preset.stepRadius,
                fontSize: preset.fontSize
            )
            break
        }
    }
    
    @objc private func undoClicked() {
        delegate?.toolbarDidClickUndo()
    }
    
    @objc private func pasteClicked() {
        delegate?.toolbarDidClickPaste()
    }
    
    @objc private func aiMaskClicked() {
        delegate?.toolbarDidClickAIMask()
    }
    
    @objc private func copyClicked() {
        delegate?.toolbarDidClickCopy()
    }
    
    @objc private func base64Clicked() {
        delegate?.toolbarDidClickBase64()
    }
    
    @objc private func ocrClicked() {
        delegate?.toolbarDidClickOCR()
    }
    
    @objc private func cliPathClicked() {
        delegate?.toolbarDidClickCLIPath()
    }
    
    @objc private func saveClicked() {
        delegate?.toolbarDidClickSave()
    }
}
