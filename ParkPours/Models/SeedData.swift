import Foundation

/// Starter checklist. These drinks were written from memory, not from current
/// menus: treat them as sample content and fix them in the app or here.
enum SeedData {
    static let resort = "Walt Disney World"

    static var fresh: PassportData {
        PassportData(parks: parks, stamps: [:], rankings: [:])
    }

    static let parks: [Park] = [
        Park(id: "epcot", name: "EPCOT", resort: resort, drinks: [
            Drink(id: "epcot-avocado-margarita", name: "La Cava Avocado Margarita", venue: "La Cava del Tequila", area: "Mexico"),
            Drink(id: "epcot-orange-slush", name: "Grand Marnier Orange Slush", venue: "Les Vins des Chefs de France", area: "France"),
            Drink(id: "epcot-leaping-leprechaun", name: "Leaping Leprechaun", venue: "Rose & Crown Pub", area: "United Kingdom"),
            Drink(id: "epcot-violet-sake", name: "Violet Sake", venue: "Kabuki Cafe", area: "Japan"),
            Drink(id: "epcot-tipsy-ducks", name: "Tipsy Ducks in Love", venue: "Joy of Tea", area: "China"),
            Drink(id: "epcot-viking-coffee", name: "Viking Coffee", venue: "Kringla Bakeri og Kafe", area: "Norway"),
            Drink(id: "epcot-grapefruit-hefeweizen", name: "Grapefruit Hefeweizen", venue: "Sommerfest", area: "Germany")
        ]),
        Park(id: "hollywood-studios", name: "Hollywood Studios", resort: resort, drinks: [
            Drink(id: "dhs-fuzzy-tauntaun", name: "Fuzzy Tauntaun", venue: "Oga's Cantina", area: "Galaxy's Edge"),
            Drink(id: "dhs-jedi-mind-trick", name: "Jedi Mind Trick", venue: "Oga's Cantina", area: "Galaxy's Edge"),
            Drink(id: "dhs-outer-rim", name: "The Outer Rim", venue: "Oga's Cantina", area: "Galaxy's Edge"),
            Drink(id: "dhs-california-sunset", name: "California Sunset", venue: "BaseLine Tap House", area: "Grand Avenue"),
            Drink(id: "dhs-grapefruit-cake-martini", name: "Grapefruit Cake Martini", venue: "Hollywood Brown Derby Lounge", area: "Hollywood Boulevard")
        ]),
        Park(id: "animal-kingdom", name: "Animal Kingdom", resort: resort, drinks: [
            Drink(id: "dak-lost-on-safari", name: "Lost on Safari", venue: "Dawa Bar", area: "Africa"),
            Drink(id: "dak-jenns-tattoo", name: "Jenn's Tattoo", venue: "Nomad Lounge", area: "Discovery Island"),
            Drink(id: "dak-tempting-tigress", name: "Tempting Tigress", venue: "Nomad Lounge", area: "Discovery Island"),
            Drink(id: "dak-rum-blossom", name: "Rum Blossom", venue: "Pongu Pongu", area: "Pandora")
        ]),
        Park(id: "magic-kingdom", name: "Magic Kingdom", resort: resort, drinks: [])
    ]
}
