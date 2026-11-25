import Foundation
import SwiftUI

/// Single source of truth. Saved as JSON in the app's Documents folder.
final class PassportStore: ObservableObject {
    @Published private(set) var data: PassportData

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("passport.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        if let raw = try? Data(contentsOf: Self.fileURL),
           let decoded = try? Self.decoder.decode(PassportData.self, from: raw) {
            data = decoded
        } else {
            data = SeedData.fresh
        }
    }

    private func persist() {
        guard let raw = try? Self.encoder.encode(data) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: Reading

    var parks: [Park] { data.parks }

    var totalStamps: Int {
        data.parks.reduce(0) { $0 + stampedCount(in: $1) }
    }

    func park(_ id: String) -> Park? {
        data.parks.first { $0.id == id }
    }

    func stamp(for drink: Drink) -> Stamp? {
        data.stamps[drink.id]
    }

    func stampedCount(in park: Park) -> Int {
        park.drinks.filter { data.stamps[$0.id] != nil }.count
    }

    func unstamped(in park: Park) -> [Drink] {
        park.drinks.filter { data.stamps[$0.id] == nil }
    }

    /// Stamped drinks in a park, best first.
    func ranked(in park: Park) -> [StampedEntry] {
        let order = data.rankings[park.id] ?? []
        var result: [StampedEntry] = []
        for drinkID in order {
            guard let drink = park.drinks.first(where: { $0.id == drinkID }),
                  let stamp = data.stamps[drinkID] else { continue }
            result.append(StampedEntry(park: park, drink: drink, stamp: stamp, rank: result.count + 1))
        }
        return result
    }

    func rank(of drink: Drink, in park: Park) -> Int? {
        ranked(in: park).first { $0.drink.id == drink.id }?.rank
    }

    func allStamped(with verdict: Verdict) -> [StampedEntry] {
        data.parks
            .flatMap { ranked(in: $0) }
            .filter { $0.stamp.verdict == verdict }
    }

    // MARK: Writing

    func saveStamp(_ stamp: Stamp, for drink: Drink, in park: Park, rank: Int) {
        data.stamps[drink.id] = stamp
        var order = (data.rankings[park.id] ?? []).filter { $0 != drink.id }
        let index = min(max(rank - 1, 0), order.count)
        order.insert(drink.id, at: index)
        data.rankings[park.id] = order
        persist()
    }

    func removeStamp(for drink: Drink, in park: Park) {
        data.stamps[drink.id]?.photos.forEach { PhotoStore.delete($0) }
        data.stamps[drink.id] = nil
        data.rankings[park.id] = (data.rankings[park.id] ?? []).filter { $0 != drink.id }
        persist()
    }

    func addDrink(name: String, venue: String, nonAlcoholic: Bool = false, to park: Park) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = data.parks.firstIndex(where: { $0.id == park.id }) else { return }
        let drink = Drink(
            id: UUID().uuidString,
            name: trimmed,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            area: "",
            nonAlcoholic: nonAlcoholic
        )
        data.parks[index].drinks.append(drink)
        persist()
    }

    func setNonAlcoholic(_ value: Bool, for drink: Drink, in park: Park) {
        guard let parkIndex = data.parks.firstIndex(where: { $0.id == park.id }),
              let drinkIndex = data.parks[parkIndex].drinks.firstIndex(where: { $0.id == drink.id }) else { return }
        data.parks[parkIndex].drinks[drinkIndex].nonAlcoholic = value
        persist()
    }

    func addPark(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        data.parks.append(Park(id: UUID().uuidString, name: trimmed, resort: "", drinks: []))
        persist()
    }
}
