import SwiftUI

/// Decides between the two-page spread (Duo open) and the cover plus
/// one-page-at-a-time book (cover screen, or any slab iPhone).
struct RootView: View {
    @EnvironmentObject private var store: PassportStore
    @AppStorage("lastParkID") private var lastParkID = ""

    @State private var spread: Spread = .index
    @State private var showCover = true
    @State private var compactPage = 0
    @State private var editTarget: EditTarget?

    var body: some View {
        GeometryReader { geo in
            let isOpen = BookLayout.isOpen(geo.size)
            ZStack {
                if isOpen {
                    PaperBackground()
                    HStack(spacing: 0) {
                        leftPage(compact: false)
                            .frame(width: geo.size.width / 2)
                        rightPage
                            .frame(width: geo.size.width / 2)
                    }
                    SpineShadow()
                } else if showCover {
                    CoverView(
                        stampCount: store.totalStamps,
                        onOpen: openBook,
                        onStamp: openToLastPark
                    )
                } else {
                    PaperBackground()
                    TabView(selection: $compactPage) {
                        leftPage(compact: true)
                            .tag(0)
                        rightPage
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .fullScreenCover(item: $editTarget) { target in
            editor(for: target)
        }
        .feedbackReporter(isActive: editTarget == nil)
    }

    // MARK: Pages

    @ViewBuilder
    private func leftPage(compact: Bool) -> some View {
        if let park = currentPark {
            ChecklistPage(
                park: park,
                compact: compact,
                onSelect: { drink in edit(drink, in: park) },
                onIndex: { go(.index) }
            )
        } else {
            ParksPage(
                compact: compact,
                onOpen: { park in go(.park(park.id)) },
                onClose: compact ? closeBook : nil
            )
        }
    }

    @ViewBuilder
    private var rightPage: some View {
        if let park = currentPark {
            StampsPage(park: park, onSelect: { drink in edit(drink, in: park) })
        } else {
            RankingsPage(onSelect: { park, drink in edit(drink, in: park) })
        }
    }

    private var currentPark: Park? {
        switch spread {
        case .index:
            return nil
        case .park(let id):
            return store.park(id)
        }
    }

    private func editor(for target: EditTarget) -> some View {
        let park = store.park(target.park.id) ?? target.park
        return StampEditor(
            park: park,
            drink: target.drink,
            existing: store.stamp(for: target.drink),
            existingRank: store.rank(of: target.drink, in: park),
            stampedCount: store.stampedCount(in: park)
        )
        .environmentObject(store)
        .preferredColorScheme(.light)
        .feedbackReporter()
    }

    // MARK: Navigation

    private func go(_ next: Spread) {
        if case .park(let id) = next {
            lastParkID = id
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            spread = next
            compactPage = 0
        }
    }

    private func edit(_ drink: Drink, in park: Park) {
        editTarget = EditTarget(park: park, drink: drink)
    }

    private func openBook() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showCover = false
        }
    }

    private func closeBook() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showCover = true
        }
    }

    /// "Stamp a drink" from the cover: jump straight to the last park's checklist.
    private func openToLastPark() {
        if let park = store.park(lastParkID) ?? store.parks.first {
            go(.park(park.id))
        }
        openBook()
    }
}
