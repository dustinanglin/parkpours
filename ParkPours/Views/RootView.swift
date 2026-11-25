import SwiftUI

/// Decides between the two-page spread (Duo open) and the cover plus
/// one-page-at-a-time book (cover screen, or any slab iPhone), and builds the
/// pages of the book.
struct RootView: View {
    @EnvironmentObject private var store: PassportStore
    @AppStorage("lastParkID") private var lastParkID = ""

    @State private var spread: Spread = .index
    @State private var showCover = true
    @State private var pageIndex = 0
    @State private var editTarget: EditTarget?

    var body: some View {
        GeometryReader { geo in
            let isOpen = BookLayout.isOpen(BookLayout.windowSize(geo))
            ZStack {
                if !isOpen && showCover {
                    CoverView(
                        stampCount: store.totalStamps,
                        onOpen: openBook,
                        onStamp: openToLastPark
                    )
                } else {
                    PaperBackground()
                    BookPager(pages: pages(compact: !isOpen), isOpen: isOpen, index: $pageIndex)
                        .id(pagerID(isOpen: isOpen))
                        .ignoresSafeArea()
                    if isOpen {
                        SpineShadow()
                    }
                }
            }
            .onAppear {
                OrientationLock.apply(isOpen: isOpen)
            }
            .onChange(of: isOpen) { _, nowOpen in
                OrientationLock.apply(isOpen: nowOpen)
            }
            .fullScreenCover(item: $editTarget) { target in
                editor(for: target, isOpen: isOpen)
            }
            .feedbackReporter(isActive: editTarget == nil)
        }
        // The keyboard must not change the open/closed decision.
        .ignoresSafeArea(.keyboard)
    }

    // MARK: Pages

    /// A new id rebuilds the pager: needed when the book opens or closes, and
    /// when moving between the index and a park.
    private func pagerID(isOpen: Bool) -> String {
        switch spread {
        case .index:
            return "index-\(isOpen)"
        case .park(let id):
            return "park-\(id)-\(isOpen)"
        }
    }

    private func pages(compact: Bool) -> [BookPage] {
        if case .park(let id) = spread, let park = store.park(id) {
            return [
                page("checklist-\(id)", ChecklistPage(
                    park: park,
                    compact: compact,
                    onSelect: { drink in edit(drink, in: park) },
                    onIndex: { go(.index) }
                )),
                page("stamps-\(id)", StampsPage(
                    park: park,
                    onSelect: { drink in edit(drink, in: park) }
                ))
            ]
        }

        var result = [
            page("parks", ParksPage(
                compact: compact,
                onOpen: { park in go(.park(park.id)) },
                onClose: compact ? closeBook : nil
            )),
            page("rankings", RankingsPage(
                onSelect: { park, drink in edit(drink, in: park) }
            ))
        ]

        // All stamps: one page per park that has at least one stamp.
        let stamped = store.parks.filter { store.stampedCount(in: $0) > 0 }
        if stamped.isEmpty {
            result.append(page("all-stamps-empty", AllStampsEmptyPage()))
        }
        for park in stamped {
            result.append(page("all-stamps-\(park.id)", StampsPage(
                park: park,
                showsTitle: true,
                onOpenPark: { go(.park(park.id)) },
                onSelect: { drink in edit(drink, in: park) }
            )))
        }
        return result
    }

    /// Pages are hosted outside the SwiftUI tree, so each one carries its own
    /// paper, store and styling.
    private func page<Content: View>(_ id: String, _ content: Content) -> BookPage {
        BookPage(id: id, view: AnyView(
            ZStack {
                PaperBackground()
                content
            }
            .environmentObject(store)
            .preferredColorScheme(.light)
            .tint(Theme.cover)
        ))
    }

    private func editor(for target: EditTarget, isOpen: Bool) -> some View {
        let park = store.park(target.park.id) ?? target.park
        return StampEditor(
            park: park,
            drink: target.drink,
            existing: store.stamp(for: target.drink),
            existingRank: store.rank(of: target.drink, in: park),
            stampedCount: store.stampedCount(in: park),
            isOpen: isOpen
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
        spread = next
        pageIndex = 0
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

/// Shown in the "all stamps" section before anything has been stamped.
struct AllStampsEmptyPage: View {
    var body: some View {
        PageScaffold(leading: "ALL STAMPS", trailing: "") {
            Text("All stamps")
                .font(Theme.serif(26, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Each park gets a page here once it has a stamp.")
                .font(Theme.mono(13))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        } footer: {
            EmptyView()
        }
    }
}
