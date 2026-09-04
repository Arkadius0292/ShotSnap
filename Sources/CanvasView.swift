import Cocoa

protocol CanvasViewDelegate: AnyObject {
    func canvasDidUpdateAnnotations(_ canvas: CanvasView)
    func canvasDidSelectAnnotation(_ annotation: BaseAnnotation?)
    func canvasDidChangeSize(_ canvas: CanvasView, newSize: CGSize)
}

// MARK: - Custom Multiline Text View for In-place Editing
final class CanvasTextView: NSTextView {
    weak var canvasView: CanvasView?
    
    override func keyDown(with event: NSEvent) {
        let isCmd = event.modifierFlags.contains(.command)
        if event.keyCode == 36 && isCmd { // Cmd + Return / Enter commits multiline text
            canvasView?.commitActiveTextField()
            return
        } else if event.keyCode == 53 { // Escape cancels editing
            canvasView?.cancelActiveTextField()
            return
        }
        super.keyDown(with: event)
    }
}

final class CanvasView: NSView, NSTextViewDelegate {
    weak var delegate: CanvasViewDelegate?
    
    var baseImage: NSImage?
    var baseImageRect: CGRect = .zero
    
    func setBaseImage(_ image: NSImage, initialRect: CGRect) {
        self.baseImage = image
        self.baseImageRect = initialRect
        self.stepCounter = 1
        self.annotations.removeAll()
        self.selectedAnnotation = nil
        self.undoStack.removeAll()
        self.redoStack.removeAll()
        needsDisplay = true
    }
    
    var currentTool: ToolType = .arrow {
        didSet {
            commitActiveTextField()
            if currentTool != .select {
                deselectAll()
            }
            updateCursor()
            needsDisplay = true
        }
    }
    
    var currentColor: NSColor = NSColor(red: 1.0, green: 0.22, blue: 0.37, alpha: 1.0) {
        didSet {
            if let selected = selectedAnnotation {
                recordUndo()
                selected.color = currentColor
                needsDisplay = true
                delegate?.canvasDidUpdateAnnotations(self)
            }
        }
    }
    
    var currentLineWidth: CGFloat = 4.5
    var currentStepRadius: CGFloat = 15.0
    var currentFontSize: CGFloat = 17.0
    
    func applySizePreset(lineWidth: CGFloat, stepRadius: CGFloat, fontSize: CGFloat) {
        self.currentLineWidth = lineWidth
        self.currentStepRadius = stepRadius
        self.currentFontSize = fontSize
        
        if let selected = selectedAnnotation {
            recordUndo()
            if let step = selected as? StepAnnotation {
                step.radius = stepRadius
            } else if let text = selected as? TextAnnotation {
                text.fontSize = fontSize
            } else {
                selected.lineWidth = lineWidth
            }
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations(self)
        }
    }
    
    private(set) var annotations: [BaseAnnotation] = []
    private(set) var selectedAnnotation: BaseAnnotation?
    
    private var undoStack: [[BaseAnnotation]] = []
    private var redoStack: [[BaseAnnotation]] = []
    
    private var activeAnnotation: BaseAnnotation?
    private var dragStartPoint: CGPoint = .zero
    private var lastDragPoint: CGPoint = .zero
    private var penPoints: [CGPoint] = []
    private var stepCounter: Int = 1
    
    // Interaction modes
    private var activeDragHandle: AnnotationHandle?
    private var isDraggingHandle = false
    private var isDraggingSelection = false
    
    // Text In-place Editor
    private var activeTextScrollView: NSScrollView?
    private var activeTextView: CanvasTextView?
    private var activeTextAnnotation: TextAnnotation?
    private var activeTextOrigin: CGPoint = .zero
    private var activeTextWidth: CGFloat = 240.0
    private var activeTextCreationRect: CGRect?
    
    override var isFlipped: Bool {
        return false
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: currentCursor)
    }
    
    private var currentCursor: NSCursor {
        switch currentTool {
        case .select:
            return .arrow
        case .arrow, .rect, .blur, .pen, .highlighter:
            return .crosshair
        case .text:
            return .iBeam
        case .step:
            return .pointingHand
        }
    }
    
    private func updateCursor() {
        window?.invalidateCursorRects(for: self)
    }
    
    // MARK: - Auto-Expand Canvas Bounds
    func checkAndExpandCanvasIfNeeded() {
        var unionRect = baseImageRect
        for a in annotations {
            unionRect = unionRect.union(a.boundingBox)
        }
        
        let pad: CGFloat = 30.0
        let leftPad: CGFloat = unionRect.minX < 0 ? ceil(abs(unionRect.minX) + pad) : 0
        let bottomPad: CGFloat = unionRect.minY < 0 ? ceil(abs(unionRect.minY) + pad) : 0
        let rightPad: CGFloat = unionRect.maxX > bounds.width ? ceil((unionRect.maxX - bounds.width) + pad) : 0
        let topPad: CGFloat = unionRect.maxY > bounds.height ? ceil((unionRect.maxY - bounds.height) + pad) : 0
        
        if leftPad > 0 || bottomPad > 0 || rightPad > 0 || topPad > 0 {
            if leftPad > 0 || bottomPad > 0 {
                let delta = CGSize(width: leftPad, height: bottomPad)
                for a in annotations {
                    a.move(by: delta)
                }
                baseImageRect.origin.x += leftPad
                baseImageRect.origin.y += bottomPad
            }
            
            let newWidth = bounds.width + leftPad + rightPad
            let newHeight = bounds.height + bottomPad + topPad
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            frame = CGRect(origin: frame.origin, size: newSize)
            needsDisplay = true
            delegate?.canvasDidChangeSize(self, newSize: newSize)
        }
    }
    
    // MARK: - Calculate Tight Export Rectangle
    func calculateExportRect() -> CGRect {
        var unionRect = baseImageRect
        for a in annotations {
            unionRect = unionRect.union(a.boundingBox)
        }
        
        let pad: CGFloat = 16.0
        let minX = unionRect.minX < baseImageRect.minX ? max(0, unionRect.minX - pad) : baseImageRect.minX
        let minY = unionRect.minY < baseImageRect.minY ? max(0, unionRect.minY - pad) : baseImageRect.minY
        let maxX = unionRect.maxX > baseImageRect.maxX ? min(bounds.width, unionRect.maxX + pad) : baseImageRect.maxX
        let maxY = unionRect.maxY > baseImageRect.maxY ? min(bounds.height, unionRect.maxY + pad) : baseImageRect.maxY
        
        let result = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).integral
        return result.width > 0 && result.height > 0 ? result : baseImageRect
    }
    
    // MARK: - Selection Management
    func selectAnnotation(_ annotation: BaseAnnotation?) {
        for a in annotations {
            a.isSelected = (a == annotation)
        }
        selectedAnnotation = annotation
        if let sel = annotation {
            currentColor = sel.color
            if let step = sel as? StepAnnotation {
                currentStepRadius = step.radius
            } else if let text = sel as? TextAnnotation {
                currentFontSize = text.fontSize
            } else {
                currentLineWidth = sel.lineWidth
            }
        }
        needsDisplay = true
        delegate?.canvasDidSelectAnnotation(annotation)
    }
    
    func deselectAll() {
        for a in annotations {
            a.isSelected = false
        }
        selectedAnnotation = nil
        needsDisplay = true
        delegate?.canvasDidSelectAnnotation(nil)
    }
    
    func deleteSelected() {
        guard let selected = selectedAnnotation else { return }
        recordUndo()
        annotations.removeAll { $0 == selected }
        selectedAnnotation = nil
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
        delegate?.canvasDidSelectAnnotation(nil)
    }
    
    // MARK: - Clipboard Paste (Images & Text)
    func pasteImage(_ image: NSImage) {
        commitActiveTextField()
        
        var imgSize = image.size
        let maxW = max(100.0, bounds.width * 0.70)
        let maxH = max(100.0, bounds.height * 0.70)
        let scale = min(1.0, min(maxW / max(1, imgSize.width), maxH / max(1, imgSize.height)))
        imgSize = CGSize(width: round(imgSize.width * scale), height: round(imgSize.height * scale))
        
        let origin = CGPoint(
            x: round((bounds.width - imgSize.width) / 2.0),
            y: round((bounds.height - imgSize.height) / 2.0)
        )
        
        let imageAnn = ImageAnnotation(image: image, rect: CGRect(origin: origin, size: imgSize))
        recordUndo()
        annotations.append(imageAnn)
        selectAnnotation(imageAnn)
        checkAndExpandCanvasIfNeeded()
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
        NSSound(named: "Hero")?.play()
    }
    
    func pasteText(_ str: String) {
        commitActiveTextField()
        let width: CGFloat = min(320.0, max(180.0, bounds.width * 0.6))
        let origin = CGPoint(
            x: max(20.0, round((bounds.width - width) / 2.0)),
            y: max(20.0, round((bounds.height - 80.0) / 2.0))
        )
        
        let textAnn = TextAnnotation(origin: origin, width: width, text: str, color: currentColor, fontSize: currentFontSize)
        recordUndo()
        annotations.append(textAnn)
        selectAnnotation(textAnn)
        checkAndExpandCanvasIfNeeded()
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
        NSSound(named: "Hero")?.play()
    }
    
    // MARK: - Undo / Redo
    private func cloneAnnotations(_ list: [BaseAnnotation]) -> [BaseAnnotation] {
        return list.compactMap { $0.copy() as? BaseAnnotation }
    }
    
    func undo() {
        commitActiveTextField()
        guard !undoStack.isEmpty else {
            if !annotations.isEmpty {
                recordUndo()
                annotations.removeAll()
                selectedAnnotation = nil
                needsDisplay = true
                delegate?.canvasDidUpdateAnnotations(self)
            }
            return
        }
        redoStack.append(cloneAnnotations(annotations))
        annotations = undoStack.popLast() ?? []
        selectedAnnotation = nil
        if stepCounter > 1 { stepCounter -= 1 }
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
    }
    
    func redo() {
        commitActiveTextField()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(cloneAnnotations(annotations))
        annotations = next
        selectedAnnotation = nil
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
    }
    
    private func recordUndo() {
        undoStack.append(cloneAnnotations(annotations))
        redoStack.removeAll()
    }
    
    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        lastDragPoint = point
        isDraggingHandle = false
        isDraggingSelection = false
        activeDragHandle = nil
        activeTextCreationRect = nil
        
        commitActiveTextField()
        
        // 1. Direct Handle Hit-Testing on currently selected element
        if let selected = selectedAnnotation, let handle = selected.hitTestHandle(point: point) {
            recordUndo()
            activeDragHandle = handle
            isDraggingHandle = true
            needsDisplay = true
            return
        }
        
        // 2. Strict Hit-Testing for element selection
        var clickedAnnotation: BaseAnnotation?
        for a in annotations.reversed() {
            if a.hitTest(point: point) {
                clickedAnnotation = a
                break
            }
        }
        
        if let target = clickedAnnotation {
            recordUndo()
            selectAnnotation(target)
            isDraggingSelection = true
            
            // Check if clicking directly on a handle of the freshly selected element
            if let handle = target.hitTestHandle(point: point) {
                activeDragHandle = handle
                isDraggingHandle = true
                isDraggingSelection = false
            }
            
            // Instant text edit mode:
            // - Double click in ANY tool mode
            // - OR Single click when Text tool (.text) is currently selected!
            if let textAnn = target as? TextAnnotation {
                if event.clickCount == 2 || currentTool == .text {
                    showTextEditor(for: textAnn)
                    isDraggingSelection = false
                }
            }
            
            needsDisplay = true
            return
        }
        
        // 3. Clicked on empty space (inside or outside screenshot): deselect and proceed with tool
        deselectAll()
        
        switch currentTool {
        case .select:
            break
            
        case .arrow:
            activeAnnotation = ArrowAnnotation(start: point, end: point, color: currentColor, lineWidth: currentLineWidth)
            
        case .rect:
            activeAnnotation = RectAnnotation(rect: CGRect(origin: point, size: .zero), color: currentColor, lineWidth: currentLineWidth)
            
        case .pen:
            penPoints = [point]
            activeAnnotation = PenAnnotation(points: penPoints, color: currentColor, lineWidth: currentLineWidth, isHighlighter: false)
            
        case .highlighter:
            penPoints = [point]
            activeAnnotation = PenAnnotation(points: penPoints, color: currentColor, lineWidth: currentLineWidth, isHighlighter: true)
            
        case .text:
            activeTextCreationRect = CGRect(origin: point, size: .zero)
            
        case .step:
            recordUndo()
            let step = StepAnnotation(center: point, number: stepCounter, color: currentColor, radius: currentStepRadius)
            annotations.append(step)
            stepCounter += 1
            checkAndExpandCanvasIfNeeded()
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations(self)
            
        case .blur:
            activeAnnotation = BlurAnnotation(rect: CGRect(origin: point, size: .zero))
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        // 1. Handle dragging
        if isDraggingHandle, let selected = selectedAnnotation, let handle = activeDragHandle {
            selected.moveHandle(handle, to: currentPoint)
            needsDisplay = true
            return
        }
        
        // 2. Selection translation
        if isDraggingSelection, let selected = selectedAnnotation {
            let delta = CGSize(width: currentPoint.x - lastDragPoint.x, height: currentPoint.y - lastDragPoint.y)
            selected.move(by: delta)
            lastDragPoint = currentPoint
            needsDisplay = true
            return
        }
        
        // 3. Drawing tool in-progress
        switch currentTool {
        case .select:
            break
            
        case .arrow:
            activeAnnotation = ArrowAnnotation(start: dragStartPoint, end: currentPoint, color: currentColor, lineWidth: currentLineWidth)
            
        case .rect:
            let rect = CGRect(
                x: min(dragStartPoint.x, currentPoint.x),
                y: min(dragStartPoint.y, currentPoint.y),
                width: abs(currentPoint.x - dragStartPoint.x),
                height: abs(currentPoint.y - dragStartPoint.y)
            )
            activeAnnotation = RectAnnotation(rect: rect, color: currentColor, lineWidth: currentLineWidth)
            
        case .pen:
            penPoints.append(currentPoint)
            activeAnnotation = PenAnnotation(points: penPoints, color: currentColor, lineWidth: currentLineWidth, isHighlighter: false)
            
        case .highlighter:
            penPoints.append(currentPoint)
            activeAnnotation = PenAnnotation(points: penPoints, color: currentColor, lineWidth: currentLineWidth, isHighlighter: true)
            
        case .text:
            activeTextCreationRect = CGRect(
                x: min(dragStartPoint.x, currentPoint.x),
                y: min(dragStartPoint.y, currentPoint.y),
                width: abs(currentPoint.x - dragStartPoint.x),
                height: abs(currentPoint.y - dragStartPoint.y)
            )
            
        case .blur:
            let rect = CGRect(
                x: min(dragStartPoint.x, currentPoint.x),
                y: min(dragStartPoint.y, currentPoint.y),
                width: abs(currentPoint.x - dragStartPoint.x),
                height: abs(currentPoint.y - dragStartPoint.y)
            )
            activeAnnotation = BlurAnnotation(rect: rect)
            
        case .step:
            break
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDraggingHandle || isDraggingSelection {
            isDraggingHandle = false
            isDraggingSelection = false
            activeDragHandle = nil
            checkAndExpandCanvasIfNeeded()
            delegate?.canvasDidUpdateAnnotations(self)
            return
        }
        
        if currentTool == .text {
            if let creationRect = activeTextCreationRect {
                activeTextCreationRect = nil
                let targetWidth = max(creationRect.width, 220.0)
                let origin = CGPoint(x: creationRect.minX, y: creationRect.minY)
                showNewTextEditor(origin: origin, width: targetWidth)
            } else {
                let point = convert(event.locationInWindow, from: nil)
                showNewTextEditor(origin: point, width: 220.0)
            }
            needsDisplay = true
            return
        }
        
        if let active = activeAnnotation {
            recordUndo()
            annotations.append(active)
            activeAnnotation = nil
            penPoints.removeAll()
            checkAndExpandCanvasIfNeeded()
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations(self)
        }
    }
    
    // MARK: - Multiline Text In-place Editing
    private func showNewTextEditor(origin: CGPoint, width: CGFloat) {
        activeTextOrigin = origin
        activeTextWidth = max(width, 100.0)
        activeTextAnnotation = nil
        
        let initialHeight: CGFloat = 50.0
        let frame = CGRect(x: origin.x, y: origin.y, width: activeTextWidth, height: initialHeight)
        createInPlaceTextView(frame: frame, initialText: "")
    }
    
    func showTextEditor(for annotation: TextAnnotation) {
        activeTextOrigin = annotation.origin
        activeTextWidth = annotation.width
        activeTextAnnotation = annotation
        
        let bounds = annotation.boundingBox
        createInPlaceTextView(frame: bounds, initialText: annotation.text)
        needsDisplay = true // Trigger redraw so activeTextAnnotation is hidden from canvas while editing
    }
    
    private func createInPlaceTextView(frame: CGRect, initialText: String) {
        commitActiveTextField()
        
        let scrollView = NSScrollView(frame: frame)
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(white: 0.10, alpha: 0.96)
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderWidth = 1.5
        scrollView.layer?.borderColor = currentColor.cgColor
        
        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)
        
        let textView = CanvasTextView(frame: CGRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.canvasView = self
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = NSColor(white: 0.10, alpha: 0.96)
        textView.textColor = currentColor
        textView.font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
        textView.textContainerInset = NSSize(width: 8, height: 6)
        
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.hyphenationFactor = 1.0
        textView.defaultParagraphStyle = style
        textView.string = initialText
        
        scrollView.documentView = textView
        addSubview(scrollView)
        
        window?.makeFirstResponder(textView)
        if !initialText.isEmpty {
            textView.selectAll(nil)
        }
        
        self.activeTextScrollView = scrollView
        self.activeTextView = textView
    }
    
    func commitActiveTextField() {
        guard let tv = activeTextView, let sv = activeTextScrollView else { return }
        let text = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existing = activeTextAnnotation {
            if text.isEmpty {
                recordUndo()
                annotations.removeAll { $0 == existing }
            } else {
                recordUndo()
                existing.text = text
                existing.width = activeTextWidth
                existing.color = currentColor
            }
        } else if !text.isEmpty {
            recordUndo()
            let annotation = TextAnnotation(
                origin: activeTextOrigin,
                width: activeTextWidth,
                text: text,
                color: currentColor,
                fontSize: currentFontSize
            )
            annotations.append(annotation)
        }
        
        sv.removeFromSuperview()
        activeTextScrollView = nil
        activeTextView = nil
        activeTextAnnotation = nil
        
        checkAndExpandCanvasIfNeeded()
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
    }
    
    func cancelActiveTextField() {
        activeTextScrollView?.removeFromSuperview()
        activeTextScrollView = nil
        activeTextView = nil
        activeTextAnnotation = nil
        needsDisplay = true
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Sleek dark canvas background across entire window surface
        context.setFillColor(NSColor(white: 0.12, alpha: 1.0).cgColor)
        context.fill(bounds)
        
        // 2. Draw subtle drop shadow card for original baseImage screenshot
        if baseImageRect.width > 0 && baseImageRect.height > 0 {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2), blur: 10, color: NSColor.black.withAlphaComponent(0.55).cgColor)
            context.setFillColor(NSColor.black.cgColor)
            let cardPath = CGPath(roundedRect: baseImageRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            context.addPath(cardPath)
            context.fillPath()
            context.restoreGState()
        }
        
        // 3. Draw base image
        if let image = baseImage {
            image.draw(in: baseImageRect)
        }
        
        // 4. Draw committed annotations (hiding the one currently being edited in-place to prevent double-rendering)
        for annotation in annotations {
            if annotation == activeTextAnnotation {
                continue
            }
            annotation.draw(in: context, baseImage: baseImage, baseImageRect: baseImageRect, viewBounds: bounds)
        }
        
        // 5. Draw active in-progress annotation
        if let active = activeAnnotation {
            active.draw(in: context, baseImage: baseImage, baseImageRect: baseImageRect, viewBounds: bounds)
        }
        
        // 6. Draw text creation preview rect if dragging text tool
        if let textRect = activeTextCreationRect, textRect.width > 2 || textRect.height > 2 {
            context.saveGState()
            context.setStrokeColor(currentColor.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(1.5)
            let dashes: [CGFloat] = [4.0, 3.0]
            context.setLineDash(phase: 0, lengths: dashes)
            context.stroke(textRect)
            context.restoreGState()
        }
    }
}
