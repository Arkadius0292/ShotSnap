import Cocoa

protocol CanvasViewDelegate: AnyObject {
    func canvasDidUpdateAnnotations(_ canvas: CanvasView)
    func canvasDidSelectAnnotation(_ annotation: BaseAnnotation?)
}

final class CanvasView: NSView, NSTextFieldDelegate {
    weak var delegate: CanvasViewDelegate?
    
    var baseImage: NSImage? {
        didSet {
            stepCounter = 1
            annotations.removeAll()
            selectedAnnotation = nil
            undoStack.removeAll()
            redoStack.removeAll()
            needsDisplay = true
        }
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
    
    private var activeTextField: NSTextField?
    private var activeTextAnnotation: TextAnnotation?
    private var activeTextOrigin: CGPoint = .zero
    
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
        
        commitActiveTextField()
        
        // 1. Direct Handle Hit-Testing on currently selected element
        if let selected = selectedAnnotation, let handle = selected.hitTestHandle(point: point) {
            recordUndo()
            activeDragHandle = handle
            isDraggingHandle = true
            needsDisplay = true
            return
        }
        
        // 2. Direct Element Hit-Testing (Works in ANY tool mode without manual tool switching!)
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
            
            // Double-click on text to edit
            if event.clickCount == 2, let textAnn = target as? TextAnnotation {
                showTextField(for: textAnn)
            }
            
            needsDisplay = true
            return
        }
        
        // 3. Clicked on empty space: deselect and proceed with current drawing tool
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
            showNewTextField(at: point)
            
        case .step:
            recordUndo()
            let step = StepAnnotation(center: point, number: stepCounter, color: currentColor, radius: currentStepRadius)
            annotations.append(step)
            stepCounter += 1
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations(self)
            
        case .blur:
            activeAnnotation = BlurAnnotation(rect: CGRect(origin: point, size: .zero))
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let currentPoint = convert(event.locationInWindow, from: nil)
        
        // 1. Handle dragging (e.g. arrow start, arrow end, arrow bend point, rect corner, text corner resize)
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
            
        case .blur:
            let rect = CGRect(
                x: min(dragStartPoint.x, currentPoint.x),
                y: min(dragStartPoint.y, currentPoint.y),
                width: abs(currentPoint.x - dragStartPoint.x),
                height: abs(currentPoint.y - dragStartPoint.y)
            )
            activeAnnotation = BlurAnnotation(rect: rect)
            
        case .text, .step:
            break
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if isDraggingHandle || isDraggingSelection {
            isDraggingHandle = false
            isDraggingSelection = false
            activeDragHandle = nil
            delegate?.canvasDidUpdateAnnotations(self)
            return
        }
        
        if let active = activeAnnotation {
            recordUndo()
            annotations.append(active)
            activeAnnotation = nil
            penPoints.removeAll()
            needsDisplay = true
            delegate?.canvasDidUpdateAnnotations(self)
        }
    }
    
    // MARK: - Text Field In-place Editing
    private func showNewTextField(at point: CGPoint) {
        activeTextOrigin = point
        activeTextAnnotation = nil
        
        let tf = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 220, height: 32))
        configureTextField(tf, initialText: "")
    }
    
    private func showTextField(for annotation: TextAnnotation) {
        activeTextOrigin = annotation.origin
        activeTextAnnotation = annotation
        
        let bounds = annotation.boundingBox
        let tf = NSTextField(frame: bounds)
        configureTextField(tf, initialText: annotation.text)
    }
    
    private func configureTextField(_ tf: NSTextField, initialText: String) {
        tf.stringValue = initialText
        tf.font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
        tf.textColor = currentColor
        tf.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        tf.wantsLayer = true
        tf.layer?.cornerRadius = 5
        tf.isBordered = true
        tf.focusRingType = .none
        tf.placeholderString = "Введите текст..."
        tf.delegate = self
        
        addSubview(tf)
        window?.makeFirstResponder(tf)
        self.activeTextField = tf
    }
    
    func commitActiveTextField() {
        guard let tf = activeTextField else { return }
        let text = tf.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existing = activeTextAnnotation {
            if text.isEmpty {
                recordUndo()
                annotations.removeAll { $0 == existing }
            } else {
                recordUndo()
                existing.text = text
                existing.color = currentColor
            }
        } else if !text.isEmpty {
            recordUndo()
            let annotation = TextAnnotation(
                origin: activeTextOrigin,
                text: text,
                color: currentColor,
                fontSize: currentFontSize
            )
            annotations.append(annotation)
        }
        
        tf.removeFromSuperview()
        activeTextField = nil
        activeTextAnnotation = nil
        needsDisplay = true
        delegate?.canvasDidUpdateAnnotations(self)
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitActiveTextField()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            activeTextField?.removeFromSuperview()
            activeTextField = nil
            activeTextAnnotation = nil
            needsDisplay = true
            return true
        }
        return false
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw base image
        if let image = baseImage {
            image.draw(in: bounds)
        }
        
        // 2. Draw committed annotations
        for annotation in annotations {
            annotation.draw(in: context, baseImage: baseImage, viewBounds: bounds)
        }
        
        // 3. Draw active in-progress annotation
        if let active = activeAnnotation {
            active.draw(in: context, baseImage: baseImage, viewBounds: bounds)
        }
    }
}
