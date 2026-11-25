import Foundation

/// Where the official catalog lives and how the app gets it.
///
/// The catalog is one JSON file on the `catalog` branch of the repo. A copy
/// ships inside the app; a newer one is downloaded when the app starts and
/// kept for next time.
enum CatalogSource {
    static let branch = "catalog"
    static let path = "catalog.json"

    static var remoteURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(FeedbackConfig.owner)/\(FeedbackConfig.repo)/\(branch)/\(path)")
    }

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("catalog.json")
    }

    static let decoder = JSONDecoder()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// The newest catalog already on the device: the downloaded copy or the
    /// one that shipped with the app, whichever has the higher version.
    static func loadLocal() -> Catalog {
        let bundled = Bundle.main.url(forResource: "catalog", withExtension: "json").flatMap(read)
        let cached = read(cacheURL)
        switch (bundled, cached) {
        case let (bundled?, cached?):
            return cached.version >= bundled.version ? cached : bundled
        case let (bundled?, nil):
            return bundled
        case let (nil, cached?):
            return cached
        default:
            return Catalog(version: 0, updated: "", parks: [])
        }
    }

    private static func read(_ url: URL) -> Catalog? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Catalog.self, from: raw)
    }

    static func cache(_ catalog: Catalog) {
        guard let raw = try? encoder.encode(catalog) else { return }
        let folder = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? raw.write(to: cacheURL, options: .atomic)
    }

    static func fetchRemote() async -> Catalog? {
        guard let url = remoteURL else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? decoder.decode(Catalog.self, from: raw)
    }
}

/// Curator only: writes a drink into the official catalog on GitHub. Needs
/// the same saved GitHub token as bug reporting.
struct CatalogPublisher {
    let token: String

    /// Adds or updates the drink, and returns the catalog as published.
    func publish(_ drink: Drink, in park: Park) async throws -> Catalog {
        do {
            return try await attempt(drink, in: park)
        } catch FeedbackError.http(let status, _, _) where status == 409 {
            // Someone else's edit landed in between: read again and retry once.
            return try await attempt(drink, in: park)
        }
    }

    private func attempt(_ drink: Drink, in park: Park) async throws -> Catalog {
        let api = GitHubIssueClient(token: token)
        let file = "contents/\(CatalogSource.path)"
        let current = try await api.send("GET", "\(file)?ref=\(CatalogSource.branch)", nil, step: "Reading the catalog")
        guard let sha = current["sha"] as? String,
              let encoded = current["content"] as? String,
              let raw = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters),
              var catalog = try? CatalogSource.decoder.decode(Catalog.self, from: raw) else {
            throw FeedbackError.badResponse
        }

        if let parkIndex = catalog.parks.firstIndex(where: { $0.id == park.id }) {
            if let drinkIndex = catalog.parks[parkIndex].drinks.firstIndex(where: { $0.id == drink.id }) {
                catalog.parks[parkIndex].drinks[drinkIndex] = drink
            } else {
                catalog.parks[parkIndex].drinks.append(drink)
            }
        } else {
            catalog.parks.append(Park(id: park.id, name: park.name, resort: park.resort, drinks: [drink]))
        }
        catalog.version += 1
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        catalog.updated = formatter.string(from: Date())

        let body = try CatalogSource.encoder.encode(catalog)
        let payload: [String: Any] = [
            "message": "Add \(drink.name) to \(park.name)",
            "content": body.base64EncodedString(),
            "sha": sha,
            "branch": CatalogSource.branch
        ]
        _ = try await api.send("PUT", file, payload, step: "Publishing to the catalog")
        return catalog
    }
}
