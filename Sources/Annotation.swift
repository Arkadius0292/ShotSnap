import Cocoa

enum ToolType: String, CaseIterable {
    case select = "Выбор"
    case arrow = "Стрелка"
    case rect = "Рамка"
    case pen = "Карандаш"
    case highlighter = "Маркер"
    case text = "Текст"
    case step = "Шаг ❶"
    case blur = "Размытие"
    
    var iconName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rect: return "rectangle"
        case .pen: return "pencil"
        case .highlighter: return "highlighter"
        case .text: return "character.cursor.ibeam"
        case .step: return "1.circle.fill"
        case .blur: return "theatermasks.fill"
        }
    }
    
    var shortcutKey: String {
        switch self {
        case .select: return "V"
        case .arrow: return "A"
        case .rect: return "R"
        case .pen: return "P"
        case .highlighter: return "H"
        case .text: return "T"
        case .step: return "S"
        case .blur: return "B"
        }
    }
    
    var description: String {
        switch self {
        case .select: return "Выбор и перемещение элементов (V)"
        case .arrow: return "Стрелка с умным скруглением (A)"
        case .rect: return "Прямоугольная рамка (R)"
        case .pen: return "Карандаш для рисования от руки (P)"
        case .highlighter: return "Полупрозрачный маркер для текста (H)"
        case .text: return "Текстовая надпись с масштабированием (T)"
        case .step: return "Автонумерованные круглые шаги ❶ ❷ ❸ (S)"
        case .blur: return "Объективное оптическое размытие фона (B)"
        }
    }
}

enum AnnotationHandle {
    case body
    case startPoint
    case endPoint
    case controlPoint
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Base Annotation Class
class BaseAnnotation: NSObject, NSCopying {
    var id = UUID()
    var color: NSColor
    var lineWidth: CGFloat
    var isSelected: Bool = false
    
    init(color: NSColor, lineWidth: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
        super.init()
    }
    
    func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        // Subclasses override
    }
    
    var boundingBox: CGRect {
        return .zero
    }
    
    func hitTest(point: CGPoint) -> Bool {
        return boundingBox.insetBy(dx: -8, dy: -8).contains(point)
    }
    
    func hitTestHandle(point: CGPoint) -> AnnotationHandle? {
        return nil
    }
    
    func moveHandle(_ handle: AnnotationHandle, to point: CGPoint) {
        // Subclasses override
    }
    
    func move(by delta: CGSize) {
        // Subclasses override
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        fatalError("Subclasses must implement copy")
    }
    
    func drawSelectionHighlight(in context: CGContext) {
        guard isSelected else { return }
        context.saveGState()
        
        let rect = boundingBox.insetBy(dx: -6, dy: -6)
        
        // Dashed border
        context.setStrokeColor(NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 0.9).cgColor)
        context.setLineWidth(1.5)
        let dashes: [CGFloat] = [5.0, 3.0]
        context.setLineDash(phase: 0, lengths: dashes)
        context.stroke(rect)
        
        // Corner handles
        let handleSize: CGFloat = 7.0
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        
        context.setLineDash(phase: 0, lengths: [])
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0).cgColor)
        context.setLineWidth(1.5)
        
        for c in corners {
            let hRect = CGRect(x: c.x - handleSize / 2, y: c.y - handleSize / 2, width: handleSize, height: handleSize)
            context.fill(hRect)
            context.stroke(hRect)
        }
        
        context.restoreGState()
    }
}

// MARK: - Arrow Annotation (Straight & Bendable Bézier Curve with Sharp Tip)
final class ArrowAnnotation: BaseAnnotation {
    var start: CGPoint
    var end: CGPoint
    var controlPoint: CGPoint?
    
    var effectiveControlPoint: CGPoint {
        return controlPoint ?? CGPoint(x: (start.x + end.x) / 2.0, y: (start.y + end.y) / 2.0)
    }
    
    init(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat, controlPoint: CGPoint? = nil) {
        self.start = start
        self.end = end
        self.controlPoint = controlPoint
        super.init(color: color, lineWidth: lineWidth)
    }
    
    override var boundingBox: CGRect {
        let mid = effectiveControlPoint
        let minX = min(start.x, min(end.x, mid.x))
        let maxX = max(start.x, max(end.x, mid.x))
        let minY = min(start.y, min(end.y, mid.y))
        let maxY = max(start.y, max(end.y, mid.y))
        let padding = max(20.0, lineWidth * 4)
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: max(maxX - minX + padding * 2, 24),
            height: max(maxY - minY + padding * 2, 24)
        )
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        if hitTestHandle(point: point) != nil {
            return true
        }
        
        let mid = effectiveControlPoint
        let steps = 24
        var prev = start
        
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let t1 = 1.0 - t
            let curr = CGPoint(
                x: t1 * t1 * start.x + 2.0 * t1 * t * mid.x + t * t * end.x,
                y: t1 * t1 * start.y + 2.0 * t1 * t * mid.y + t * t * end.y
            )
            
            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            let lenSq = dx * dx + dy * dy
            if lenSq > 0 {
                let u = max(0, min(1, ((point.x - prev.x) * dx + (point.y - prev.y) * dy) / lenSq))
                let projX = prev.x + u * dx
                let projY = prev.y + u * dy
                if hypot(point.x - projX, point.y - projY) <= max(14.0, lineWidth * 2.5) {
                    return true
                }
            }
            prev = curr
        }
        return false
    }
    
    override func hitTestHandle(point: CGPoint) -> AnnotationHandle? {
        let handleRadius: CGFloat = 12.0
        
        if hypot(point.x - start.x, point.y - start.y) <= handleRadius {
            return .startPoint
        }
        if hypot(point.x - end.x, point.y - end.y) <= handleRadius {
            return .endPoint
        }
        let mid = effectiveControlPoint
        if hypot(point.x - mid.x, point.y - mid.y) <= handleRadius + 2 {
            return .controlPoint
        }
        
        return nil
    }
    
    override func moveHandle(_ handle: AnnotationHandle, to point: CGPoint) {
        switch handle {
        case .startPoint:
            start = point
        case .endPoint:
            end = point
        case .controlPoint:
            controlPoint = point
        default:
            break
        }
    }
    
    override func move(by delta: CGSize) {
        start.x += delta.width
        start.y += delta.height
        end.x += delta.width
        end.y += delta.height
        if controlPoint != nil {
            controlPoint!.x += delta.width
            controlPoint!.y += delta.height
        }
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = ArrowAnnotation(start: start, end: end, color: color, lineWidth: lineWidth, controlPoint: controlPoint)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        let mid = effectiveControlPoint
        let dx = end.x - mid.x
        let dy = end.y - mid.y
        let distance = hypot(end.x - start.x, end.y - start.y)
        
        if distance < 3 {
            return
        }
        
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Sharp modern arrowhead parameters
        let angle = atan2(dy, dx)
        let headLength = max(15.0, lineWidth * 3.8)
        let headAngle: CGFloat = .pi / 6.5
        
        let p1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let p2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )
        
        let baseCenter = CGPoint(
            x: end.x - headLength * 0.72 * cos(angle),
            y: end.y - headLength * 0.72 * sin(angle)
        )
        
        // Draw arrow body
        context.beginPath()
        context.move(to: start)
        if controlPoint != nil {
            context.addQuadCurve(to: baseCenter, control: mid)
        } else {
            context.addLine(to: baseCenter)
        }
        context.strokePath()
        
        // Draw filled sharp arrowhead
        let arrowHead = CGMutablePath()
        arrowHead.move(to: end)
        arrowHead.addLine(to: p1)
        arrowHead.addLine(to: baseCenter)
        arrowHead.addLine(to: p2)
        arrowHead.closeSubpath()
        
        context.addPath(arrowHead)
        context.fillPath()
        
        context.restoreGState()
        
        drawSelectionHighlight(in: context)
    }
    
    override func drawSelectionHighlight(in context: CGContext) {
        guard isSelected else { return }
        context.saveGState()
        
        let mid = effectiveControlPoint
        
        if controlPoint != nil {
            context.setStrokeColor(NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 0.4).cgColor)
            context.setLineWidth(1.0)
            let dashes: [CGFloat] = [3.0, 3.0]
            context.setLineDash(phase: 0, lengths: dashes)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: mid)
            context.addLine(to: end)
            context.strokePath()
        }
        
        context.setLineDash(phase: 0, lengths: [])
        let handleSize: CGFloat = 8.0
        
        for pt in [start, end] {
            let hRect = CGRect(x: pt.x - handleSize / 2, y: pt.y - handleSize / 2, width: handleSize, height: handleSize)
            context.setFillColor(NSColor.white.cgColor)
            context.setStrokeColor(NSColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0).cgColor)
            context.setLineWidth(1.5)
            context.fillEllipse(in: hRect)
            context.strokeEllipse(in: hRect)
        }
        
        let midSize: CGFloat = 9.0
        let midRect = CGRect(x: mid.x - midSize / 2, y: mid.y - midSize / 2, width: midSize, height: midSize)
        context.setFillColor(NSColor(red: 0.0, green: 0.65, blue: 1.0, alpha: 1.0).cgColor)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.0)
        context.fillEllipse(in: midRect)
        context.strokeEllipse(in: midRect)
        
        context.restoreGState()
    }
}

// MARK: - Rect Annotation
final class RectAnnotation: BaseAnnotation {
    var rect: CGRect
    var isFilled: Bool = false
    
    init(rect: CGRect, color: NSColor, lineWidth: CGFloat, isFilled: Bool = false) {
        self.rect = rect
        self.isFilled = isFilled
        super.init(color: color, lineWidth: lineWidth)
    }
    
    override var boundingBox: CGRect {
        return rect.standardized
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        let normalized = rect.standardized
        let outer = normalized.insetBy(dx: -max(12, lineWidth), dy: -max(12, lineWidth))
        let inner = normalized.insetBy(dx: max(12, lineWidth), dy: max(12, lineWidth))
        
        if isFilled {
            return outer.contains(point)
        }
        return outer.contains(point) && !inner.contains(point)
    }
    
    override func hitTestHandle(point: CGPoint) -> AnnotationHandle? {
        let norm = rect.standardized
        let radius: CGFloat = 10.0
        
        if hypot(point.x - norm.minX, point.y - norm.minY) <= radius { return .bottomLeft }
        if hypot(point.x - norm.maxX, point.y - norm.minY) <= radius { return .bottomRight }
        if hypot(point.x - norm.minX, point.y - norm.maxY) <= radius { return .topLeft }
        if hypot(point.x - norm.maxX, point.y - norm.maxY) <= radius { return .topRight }
        
        return nil
    }
    
    override func moveHandle(_ handle: AnnotationHandle, to point: CGPoint) {
        let norm = rect.standardized
        switch handle {
        case .bottomLeft:
            rect = CGRect(x: point.x, y: point.y, width: norm.maxX - point.x, height: norm.maxY - point.y).standardized
        case .bottomRight:
            rect = CGRect(x: norm.minX, y: point.y, width: point.x - norm.minX, height: norm.maxY - point.y).standardized
        case .topLeft:
            rect = CGRect(x: point.x, y: norm.minY, width: norm.maxX - point.x, height: point.y - norm.minY).standardized
        case .topRight:
            rect = CGRect(x: norm.minX, y: norm.minY, width: point.x - norm.minX, height: point.y - norm.minY).standardized
        default:
            break
        }
    }
    
    override func move(by delta: CGSize) {
        rect.origin.x += delta.width
        rect.origin.y += delta.height
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = RectAnnotation(rect: rect, color: color, lineWidth: lineWidth, isFilled: isFilled)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        context.saveGState()
        let normalized = rect.standardized
        let cornerRadius: CGFloat = 6.0
        let path = CGPath(roundedRect: normalized, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        
        if isFilled {
            context.setFillColor(color.withAlphaComponent(0.25).cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.addPath(path)
        context.strokePath()
        
        context.restoreGState()
        
        drawSelectionHighlight(in: context)
    }
}

// MARK: - Pen Annotation
final class PenAnnotation: BaseAnnotation {
    var points: [CGPoint]
    var isHighlighter: Bool = false
    
    init(points: [CGPoint], color: NSColor, lineWidth: CGFloat, isHighlighter: Bool = false) {
        self.points = points
        self.isHighlighter = isHighlighter
        super.init(color: color, lineWidth: lineWidth)
    }
    
    override var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let pad = max(10, lineWidth)
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        guard points.count > 1 else { return false }
        for i in 0..<(points.count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let lenSq = dx * dx + dy * dy
            if lenSq == 0 { continue }
            let t = max(0, min(1, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / lenSq))
            let projX = p1.x + t * dx
            let projY = p1.y + t * dy
            if hypot(point.x - projX, point.y - projY) <= max(12.0, lineWidth * 1.5) {
                return true
            }
        }
        return false
    }
    
    override func move(by delta: CGSize) {
        for i in 0..<points.count {
            points[i].x += delta.width
            points[i].y += delta.height
        }
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = PenAnnotation(points: points, color: color, lineWidth: lineWidth, isHighlighter: isHighlighter)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        guard points.count > 1 else { return }
        context.saveGState()
        
        if isHighlighter {
            context.setAlpha(0.38)
            context.setBlendMode(.multiply)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(max(lineWidth * 3.5, 18.0))
        } else {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
        }
        
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.beginPath()
        context.move(to: points[0])
        for p in points.dropFirst() {
            context.addLine(to: p)
        }
        context.strokePath()
        context.restoreGState()
        
        drawSelectionHighlight(in: context)
    }
}

// MARK: - Text Annotation (Scalable via corner handles)
final class TextAnnotation: BaseAnnotation {
    var origin: CGPoint
    var text: String
    var fontSize: CGFloat
    
    init(origin: CGPoint, text: String, color: NSColor, fontSize: CGFloat = 17.0) {
        self.origin = origin
        self.text = text
        self.fontSize = fontSize
        super.init(color: color, lineWidth: 1.0)
    }
    
    override var boundingBox: CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        let size = attr.size()
        let padding: CGFloat = 6.0
        return CGRect(
            x: origin.x - padding,
            y: origin.y - padding,
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        return boundingBox.contains(point)
    }
    
    override func hitTestHandle(point: CGPoint) -> AnnotationHandle? {
        let box = boundingBox
        let radius: CGFloat = 10.0
        
        if hypot(point.x - box.minX, point.y - box.minY) <= radius { return .bottomLeft }
        if hypot(point.x - box.maxX, point.y - box.minY) <= radius { return .bottomRight }
        if hypot(point.x - box.minX, point.y - box.maxY) <= radius { return .topLeft }
        if hypot(point.x - box.maxX, point.y - box.maxY) <= radius { return .topRight }
        
        return nil
    }
    
    override func moveHandle(_ handle: AnnotationHandle, to point: CGPoint) {
        let box = boundingBox
        let currentHeight = max(box.height - 12.0, 10.0)
        var targetHeight: CGFloat = currentHeight
        
        switch handle {
        case .topRight, .topLeft:
            targetHeight = max(10.0, point.y - origin.y)
        case .bottomRight, .bottomLeft:
            targetHeight = max(10.0, (origin.y + currentHeight) - point.y)
            origin.y = point.y
        default:
            break
        }
        
        if targetHeight > 5 {
            let scaleRatio = targetHeight / currentHeight
            let newFontSize = max(10.0, min(80.0, fontSize * scaleRatio))
            fontSize = round(newFontSize)
        }
    }
    
    override func move(by delta: CGSize) {
        origin.x += delta.width
        origin.y += delta.height
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = TextAnnotation(origin: origin, text: text, color: color, fontSize: fontSize)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        guard !text.isEmpty else { return }
        
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        
        let attrString = NSAttributedString(string: text, attributes: textAttributes)
        let bgRect = boundingBox
        
        context.saveGState()
        context.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
        let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        context.addPath(bgPath)
        context.fillPath()
        
        context.setStrokeColor(color.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        context.addPath(bgPath)
        context.strokePath()
        context.restoreGState()
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        attrString.draw(at: origin)
        NSGraphicsContext.restoreGraphicsState()
        
        drawSelectionHighlight(in: context)
    }
}

// MARK: - Step Marker (Dynamically resizable badge)
final class StepAnnotation: BaseAnnotation {
    var center: CGPoint
    var number: Int
    var radius: CGFloat = 15.0
    
    init(center: CGPoint, number: Int, color: NSColor, radius: CGFloat = 15.0) {
        self.center = center
        self.number = number
        self.radius = radius
        super.init(color: color, lineWidth: 2.0)
    }
    
    override var boundingBox: CGRect {
        return CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        return hypot(point.x - center.x, point.y - center.y) <= radius + 6
    }
    
    override func move(by delta: CGSize) {
        center.x += delta.width
        center.y += delta.height
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = StepAnnotation(center: center, number: number, color: color, radius: radius)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        context.saveGState()
        let circleRect = boundingBox
        
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)
        
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: circleRect)
        context.restoreGState()
        
        let numStr = "\(number)"
        let fontSize = radius * 1.15
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: numStr, attributes: attr)
        let strSize = str.size()
        let textPoint = CGPoint(
            x: center.x - strSize.width / 2,
            y: center.y - strSize.height / 2 + 0.5
        )
        
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        str.draw(at: textPoint)
        NSGraphicsContext.restoreGraphicsState()
        
        drawSelectionHighlight(in: context)
    }
}

// MARK: - Blur / Pixelate (Optical Lens / Bokeh Blur)
final class BlurAnnotation: BaseAnnotation {
    var rect: CGRect
    
    init(rect: CGRect) {
        self.rect = rect
        super.init(color: .white, lineWidth: 1.0)
    }
    
    override var boundingBox: CGRect {
        return rect.standardized
    }
    
    override func hitTest(point: CGPoint) -> Bool {
        return boundingBox.contains(point)
    }
    
    override func move(by delta: CGSize) {
        rect.origin.x += delta.width
        rect.origin.y += delta.height
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = BlurAnnotation(rect: rect)
        copy.isSelected = isSelected
        return copy
    }
    
    override func draw(in context: CGContext, baseImage: NSImage?, viewBounds: CGRect) {
        guard let baseImage = baseImage,
              let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        let normalized = rect.standardized
        guard normalized.width > 2 && normalized.height > 2 else { return }
        
        let scaleX = CGFloat(cgImage.width) / viewBounds.width
        let scaleY = CGFloat(cgImage.height) / viewBounds.height
        
        let cropRect = CGRect(
            x: normalized.origin.x * scaleX,
            y: normalized.origin.y * scaleY,
            width: normalized.width * scaleX,
            height: normalized.height * scaleY
        )
        
        guard let cropped = cgImage.cropping(to: cropRect) else { return }
        
        let ciImage = CIImage(cgImage: cropped).clampedToExtent()
        
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(14.0, forKey: kCIInputRadiusKey)
        
        let ciContext = CIContext(cgContext: context, options: nil)
        if let output = filter?.outputImage,
           let blurred = ciContext.createCGImage(output, from: CGRect(origin: .zero, size: cropRect.size)) {
            context.saveGState()
            
            let cornerRadius: CGFloat = 6.0
            let path = CGPath(roundedRect: normalized, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            context.clip()
            
            context.draw(blurred, in: normalized)
            
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
            context.setLineWidth(1.0)
            context.addPath(path)
            context.strokePath()
            
            context.restoreGState()
        }
        
        drawSelectionHighlight(in: context)
    }
}
