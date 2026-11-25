import UIKit
import Vision

/// Reads the lines of text off a photo of a menu. Runs entirely on the
/// device; nothing is uploaded.
enum MenuTextReader {
    static func lines(in images: [UIImage]) async -> [String] {
        var all: [String] = []
        for image in images {
            all += await recognise(image)
        }
        return clean(all)
    }

    private static func recognise(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = cgOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try? handler.perform([request])
                let found = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: found)
            }
        }
    }

    /// Drops prices and noise, and removes repeats. What is left is a mix of
    /// drink names and descriptions; the person picks the names.
    static func clean(_ raw: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for line in raw {
            var text = line.replacingOccurrences(
                of: #"\s*(\$\s*\d{1,3}([.,]\d{2})?|\d{1,3}[.,]\d{2})\s*$"#,
                with: "",
                options: .regularExpression
            )
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: " .·•-–—|*:\t"))
            let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard text.count >= 3, letters >= 3, letters * 2 >= text.count else { continue }
            guard seen.insert(text.lowercased()).inserted else { continue }
            result.append(text)
        }
        return result
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
