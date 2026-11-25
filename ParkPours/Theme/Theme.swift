import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Concept A, "Passport office". Fonts are system stand-ins for the mockup's
/// Libre Caslon (serif), IBM Plex Mono (mono) and Oswald (stamp); swap them
/// here once the real fonts are bundled.
enum Theme {
    static let paper = Color(hex: 0xEDF1EC)
    static let ink = Color(hex: 0x1F2A30)
    static let muted = Color(hex: 0x47565E)
    static let rule = Color(hex: 0x7C8A90)
    static let guilloche = Color(hex: 0x2E5E6E)
    static let cover = Color(hex: 0x5B1A22)
    static let gold = Color(hex: 0xE3C582)
    static let cream = Color(hex: 0xF3E3BC)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func stamp(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

enum BookLayout {
    /// True when the window is big enough for a two-page spread. The open Duo
    /// is expected to report roughly 890 x 626 points; a slab iPhone or the
    /// Duo's cover screen falls back to one page at a time.
    static func isOpen(_ size: CGSize) -> Bool {
        size.width >= 700 && size.height >= 500
    }
}

enum Formats {
    private static let stampDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    static func stamp(_ date: Date) -> String {
        stampDate.string(from: date).uppercased()
    }

    /// Machine-readable-zone style line: letters and digits, everything else "<".
    static func mrz(_ parts: [String], length: Int = 34) -> String {
        let joined = parts.joined(separator: "<<").uppercased()
        var out = ""
        for scalar in joined.unicodeScalars {
            let isLetter = scalar.value >= 65 && scalar.value <= 90
            let isDigit = scalar.value >= 48 && scalar.value <= 57
            out.append(isLetter || isDigit ? Character(scalar) : "<")
        }
        if out.count > length {
            return String(out.prefix(length))
        }
        return out + String(repeating: "<", count: length - out.count)
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(12, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(Theme.cover)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct PrimaryLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(title)
                .font(Theme.stamp(15, weight: .semibold))
                .tracking(1.6)
        }
        .foregroundStyle(Theme.cream)
        .padding(.horizontal, 20)
        .frame(minHeight: 44)
        .background(Theme.cover)
    }
}
