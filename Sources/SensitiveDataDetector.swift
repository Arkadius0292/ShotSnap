import Cocoa
import Vision

final class SensitiveDataDetector {
    
    // Regular expression patterns for sensitive data
    private static let patterns: [(name: String, regex: NSRegularExpression, matchGroup: Int)] = {
        var list: [(String, NSRegularExpression, Int)] = []
        
        func add(_ name: String, _ pattern: String, _ group: Int = 0) {
            if let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                list.append((name, rx, group))
            }
        }
        
        // 1. API Keys & Secrets
        add("OpenAI API Key", "sk-[a-zA-Z0-9_-]{20,}")
        add("GitHub Token", "(?:ghp|gho|ghu|ghs|ghr|github_pat)_[A-Za-z0-9_]{30,}")
        add("AWS Access Key", "AKIA[0-9A-Z]{16}")
        add("Google API Key", "AIza[0-9A-Za-z\\-_]{35}")
        add("Slack Token", "xox[baprs]-[0-9a-zA-Z]{10,}")
        add("JWT Token", "eyJh[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]{10,}")
        add("Private Key", "-----BEGIN [A-Z ]*PRIVATE KEY-----")
        
        // 2. Passwords and Labels with secrets (e.g. password: xyz123, пароль: 12345)
        add("Password Label", "(?:password|passwd|pass|пароль|secret|api[_-]?key|секрет)\\s*[:=]\\s*([^\\s,;]+)", 1)
        add("Masked Password", "[•*]{4,}")
        
        // 3. Financial & Bank Cards
        add("Bank Card (16 digits)", "\\b(?:\\d{4}[ -]?){3}\\d{4}\\b")
        add("Bank Card (Amex 15)", "\\b\\d{4}[ -]?\\d{6}[ -]?\\d{5}\\b")
        
        // 4. Personal Data (ПДн)
        add("Email", "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}")
        add("Phone Number", "(?:\\+7|8)[\\s-]?\\(?\\d{3}\\)?[\\s-]?\\d{3}[\\s-]?\\d{2}[\\s-]?\\d{2}")
        add("Russian Passport", "\\b\\d{2}\\s?\\d{2}\\s?\\d{6}\\b")
        add("SNILS", "\\b\\d{3}-\\d{3}-\\d{3}\\s?\\d{2}\\b")
        
        return list
    }()
    
    /// Scans an image locally using Apple Vision and returns BlurAnnotation overlays for sensitive data
    static func detectSensitiveAreas(
        in image: NSImage,
        baseImageRect: CGRect,
        completion: @escaping ([BlurAnnotation]) -> Void
    ) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { (request, error) in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                var blurRects: [CGRect] = []
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let lineText = topCandidate.string
                    let fullRange = NSRange(location: 0, length: (lineText as NSString).length)
                    
                    for (_, regex, matchGroup) in patterns {
                        let matches = regex.matches(in: lineText, options: [], range: fullRange)
                        for match in matches {
                            let targetRange = (matchGroup < match.numberOfRanges && match.range(at: matchGroup).location != NSNotFound)
                                ? match.range(at: matchGroup)
                                : match.range
                            
                            guard targetRange.length > 0,
                                  let swiftRange = Range(targetRange, in: lineText) else { continue }
                            
                            // Try extracting precise substring bounding box from Vision
                            var matchedBox: CGRect?
                            if let boxObservation = try? topCandidate.boundingBox(for: swiftRange) {
                                matchedBox = boxObservation.boundingBox
                            } else {
                                // Fallback to entire line bounding box if sub-box calculation fails
                                matchedBox = observation.boundingBox
                            }
                            
                            if let normBox = matchedBox {
                                // Convert Vision normalized coordinates (0..1, origin bottom-left) to baseImageRect
                                let x = baseImageRect.minX + normBox.origin.x * baseImageRect.width - 3.0
                                let y = baseImageRect.minY + normBox.origin.y * baseImageRect.height - 2.0
                                let w = normBox.width * baseImageRect.width + 6.0
                                let h = normBox.height * baseImageRect.height + 4.0
                                
                                let rect = CGRect(x: x, y: y, width: w, height: h)
                                blurRects.append(rect)
                            }
                        }
                    }
                }
                
                // Merge overlapping or adjacent blur rects for clean visual presentation
                let merged = mergeOverlappingRects(blurRects)
                let annotations = merged.map { BlurAnnotation(rect: $0) }
                
                DispatchQueue.main.async {
                    completion(annotations)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ru-RU", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private static func mergeOverlappingRects(_ rects: [CGRect]) -> [CGRect] {
        guard !rects.isEmpty else { return [] }
        var result: [CGRect] = []
        
        for r in rects {
            var didMerge = false
            for i in 0..<result.count {
                if result[i].insetBy(dx: -4, dy: -4).intersects(r) {
                    result[i] = result[i].union(r)
                    didMerge = true
                    break
                }
            }
            if !didMerge {
                result.append(r)
            }
        }
        return result
    }
}
