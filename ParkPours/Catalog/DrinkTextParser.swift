import CoreGraphics
import Foundation

/// A piece of text the camera found inside the scan box.
struct ScannedBlock {
    let text: String
    /// Distance from the top of the view, for reading order.
    let top: CGFloat
}

/// Turns the text found in the scan box into a drink name and description.
/// The box holds one drink, so the first line is taken as the name and the
/// rest as the description. The person checks both before adding.
enum DrinkTextParser {
    struct Result {
        var name: String
        var details: String
        /// Every line found, in reading order, so a different one can be
        /// picked as the name.
        var lines: [String]
    }

    static func parse(_ blocks: [ScannedBlock]) -> Result {
        let lines = blocks
            .sorted { $0.top < $1.top }
            .flatMap { $0.text.components(separatedBy: .newlines) }
            .map(clean)
            .filter { !$0.isEmpty }
        return split(lines, nameIndex: 0)
    }

    /// Rebuilds the result with a different line as the name.
    static func split(_ lines: [String], nameIndex: Int) -> Result {
        guard lines.indices.contains(nameIndex) else {
            return Result(name: "", details: "", lines: lines)
        }
        var rest = lines
        let name = rest.remove(at: nameIndex)
        return Result(name: tidyCase(name), details: rest.joined(separator: " "), lines: lines)
    }

    /// Strips a trailing price and stray punctuation.
    private static func clean(_ line: String) -> String {
        let withoutPrice = line.replacingOccurrences(
            of: #"\s*(\$\s*\d{1,3}([.,]\d{2})?|\d{1,3}[.,]\d{2})\s*$"#,
            with: "",
            options: .regularExpression
        )
        let trimmed = withoutPrice.trimmingCharacters(in: CharacterSet(charactersIn: " .·•-–—|*:\t"))
        let letters = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return letters >= 2 ? trimmed : ""
    }

    /// Menus often print names in capitals. "LEAPING LEPRECHAUN" becomes
    /// "Leaping Leprechaun"; mixed-case names are left alone.
    private static func tidyCase(_ name: String) -> String {
        guard name == name.uppercased(), name != name.lowercased() else { return name }
        return name
            .lowercased()
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
