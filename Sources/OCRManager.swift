import Cocoa
import Vision

final class OCRManager {
    static let shared = OCRManager()
    
    private init() {}
    
    func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // Sort lines by vertical position (top to bottom), then left to right
                let sorted = observations.sorted { obs1, obs2 in
                    // In Vision, coordinates are normalized (0,0 bottom-left, 1,1 top-right)
                    let y1 = obs1.boundingBox.midY
                    let y2 = obs2.boundingBox.midY
                    if abs(y1 - y2) > 0.02 {
                        return y1 > y2 // Higher Y first (top of image)
                    }
                    return obs1.boundingBox.minX < obs2.boundingBox.minX
                }
                
                var lines: [String] = []
                for obs in sorted {
                    if let candidate = obs.topCandidates(1).first {
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            lines.append(text)
                        }
                    }
                }
                
                let fullText = lines.joined(separator: "\n")
                DispatchQueue.main.async {
                    completion(fullText.isEmpty ? nil : fullText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["ru-RU", "en-US"]
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
