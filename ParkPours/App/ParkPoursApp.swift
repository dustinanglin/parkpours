import SwiftUI

@main
struct ParkPoursApp: App {
    @StateObject private var store = PassportStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(Theme.cover)
        }
    }
}
