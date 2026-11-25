import SwiftUI

/// The verdict is the stamp: four inks, best to worst.
enum Verdict: String, Codable, CaseIterable, Identifiable {
    case worthTheLine
    case solidPour
    case fine
    case denied

    var id: String { rawValue }

    var label: String {
        switch self {
        case .worthTheLine: return "WORTH THE LINE"
        case .solidPour: return "SOLID POUR"
        case .fine: return "FINE"
        case .denied: return "DENIED"
        }
    }

    var ink: Color {
        switch self {
        case .worthTheLine: return Color(hex: 0x17573A)
        case .solidPour: return Color(hex: 0x1B3A8A)
        case .fine: return Color(hex: 0x4B2A7A)
        case .denied: return Color(hex: 0x8E1B24)
        }
    }
}

struct Drink: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var venue: String
    var area: String

    var subtitle: String {
        [venue, area].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct Park: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var resort: String
    var drinks: [Drink]
}

struct Stamp: Codable, Hashable {
    var verdict: Verdict
    var date: Date
    var notes: String
}

/// Everything the passport persists. `stamps` is keyed by drink id;
/// `rankings` is keyed by park id and holds drink ids, best first.
struct PassportData: Codable {
    var parks: [Park]
    var stamps: [String: Stamp]
    var rankings: [String: [String]]
}

struct StampedEntry: Identifiable {
    let park: Park
    let drink: Drink
    let stamp: Stamp
    let rank: Int

    var id: String { drink.id }
}

struct EditTarget: Identifiable {
    let park: Park
    let drink: Drink

    var id: String { drink.id }
}

enum Spread: Equatable {
    case index
    case park(String)
}
