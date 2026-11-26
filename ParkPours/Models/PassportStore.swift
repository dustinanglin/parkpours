import Foundation
import SwiftUI

/// Single source of truth. The official catalog and the person's own
/// passport are stored separately and merged into `parks` for the views.
final class PassportStore: ObservableObject {
    /// Personal data, saved as JSON in the app's Documents folder.
    @Published private(set) var data: PassportData
    @Published private(set) var catalog: Catalog
    /// Catalog parks and drinks, plus whatever this person added.
    @Published private(set) var parks: [Park] = []

    private var customDrinkIDs: Set<String> = []

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
            data = PassportData(parks: [], stamps: [:], rankings: [:])
        }
        catalog = CatalogSource.loadLocal()
        // Passports from before the catalog existed hold a full copy of the
        // starter drinks. Drop anything the catalog now provides.
        if pruneCatalogCopies() {
            save()
        }
        rebuild()
    }

    private func save() {
        guard let raw = try? Self.encoder.encode(data) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    private func persist() {
        save()
        rebuild()
    }

    /// Merges the catalog with the person's own parks and drinks.
    private func rebuild() {
        var custom = Dictionary(data.parks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var catalogDrinkIDs: Set<String> = []
        var merged: [Park] = []

        for var park in catalog.parks {
            let known = Set(park.drinks.map { $0.id })
            catalogDrinkIDs.formUnion(known)
            park.drinks = park.drinks.filter { !$0.retired || data.stamps[$0.id] != nil }
            if let mine = custom.removeValue(forKey: park.id) {
                park.drinks += mine.drinks.filter { !known.contains($0.id) }
            }
            merged.append(park)
        }
        // Parks this person added, in the order they added them.
        for park in data.parks where custom[park.id] != nil {
            merged.append(park)
            custom[park.id] = nil
        }

        customDrinkIDs = Set(data.parks.flatMap { $0.drinks.map { $0.id } }).subtracting(catalogDrinkIDs)
        parks = merged
        Self.summary = "catalog v\(catalog.version) with \(catalogDrinkIDs.count) drinks, "
            + "\(customDrinkIDs.count) personal drinks, \(data.stamps.count) stamps"
    }

    /// One line describing what is stored, attached to bug reports.
    private(set) static var summary = "not loaded"

    /// Removes personal copies of drinks the catalog has. Returns true if
    /// anything changed.
    private func pruneCatalogCopies() -> Bool {
        let catalogParkIDs = Set(catalog.parks.map { $0.id })
        let catalogDrinkIDs = Set(catalog.parks.flatMap { $0.drinks.map { $0.id } })
        var changed = false
        var kept: [Park] = []
        for var park in data.parks {
            let before = park.drinks.count
            park.drinks.removeAll { catalogDrinkIDs.contains($0.id) }
            if park.drinks.count != before {
                changed = true
            }
            if park.drinks.isEmpty && catalogParkIDs.contains(park.id) {
                changed = true
                continue
            }
            kept.append(park)
        }
        if changed {
            data.parks = kept
        }
        return changed
    }

    // MARK: Catalog

    /// Takes a catalog if it is at least as new as the one in use.
    @MainActor
    func adopt(_ newCatalog: Catalog) {
        guard newCatalog.version >= catalog.version else { return }
        catalog = newCatalog
        CatalogSource.cache(newCatalog)
        if pruneCatalogCopies() {
            save()
        }
        rebuild()
    }

    /// Checks for a newer catalog. Quietly keeps the current one on failure.
    @MainActor
    func refreshCatalog() async {
        if let remote = await CatalogSource.fetchRemote() {
            adopt(remote)
        }
    }

    /// True for a drink this person added, as opposed to a catalog drink.
    func isCustom(_ drink: Drink) -> Bool {
        customDrinkIDs.contains(drink.id)
    }

    // MARK: Reading

    var totalStamps: Int {
        parks.reduce(0) { $0 + stampedCount(in: $1) }
    }

    func park(_ id: String) -> Park? {
        parks.first { $0.id == id }
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
        parks
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

    /// Adds a personal drink to a park, whether the park is from the catalog
    /// or one this person created.
    func addDrink(name: String, venue: String, details: String = "", nonAlcoholic: Bool = false, to park: Park) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var drink = Drink(
            id: UUID().uuidString,
            name: trimmed,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            area: "",
            nonAlcoholic: nonAlcoholic
        )
        drink.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = data.parks.firstIndex(where: { $0.id == park.id }) {
            data.parks[index].drinks.append(drink)
        } else {
            data.parks.append(Park(id: park.id, name: park.name, resort: park.resort, drinks: [drink]))
        }
        persist()
    }

    /// Replaces a personal drink with an edited copy (same id).
    func updateDrink(_ updated: Drink, in park: Park) {
        guard let parkIndex = data.parks.firstIndex(where: { $0.id == park.id }),
              let drinkIndex = data.parks[parkIndex].drinks.firstIndex(where: { $0.id == updated.id }) else { return }
        data.parks[parkIndex].drinks[drinkIndex] = updated
        persist()
    }

    /// Deletes a personal drink along with its stamp, photos and ranking.
    func deleteDrink(_ drink: Drink, in park: Park) {
        guard let parkIndex = data.parks.firstIndex(where: { $0.id == park.id }),
              data.parks[parkIndex].drinks.contains(where: { $0.id == drink.id }) else { return }
        data.parks[parkIndex].drinks.removeAll { $0.id == drink.id }
        data.stamps[drink.id]?.photos.forEach { PhotoStore.delete($0) }
        data.stamps[drink.id] = nil
        data.rankings[park.id] = (data.rankings[park.id] ?? []).filter { $0 != drink.id }
        persist()
    }

    /// Only personal drinks can be changed here; catalog drinks are fixed.
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
