import SwiftUI

/// Right page of a park spread: the stamps collected so far, best first.
struct StampsPage: View {
    @EnvironmentObject private var store: PassportStore
    let park: Park
    let onSelect: (Drink) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var entries: [StampedEntry] {
        store.ranked(in: park)
    }

    private var remaining: [Drink] {
        store.unstamped(in: park)
    }

    var body: some View {
        PageScaffold(leading: "ENTRIES · ENTRÉES", trailing: park.name.uppercased()) {
            if park.drinks.isEmpty {
                Text("No drinks listed for this park yet. Add one from the checklist page.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry.drink)
                            } label: {
                                StampView(drink: entry.drink, stamp: entry.stamp)
                                    .frame(maxWidth: .infinity, minHeight: 156)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if !remaining.isEmpty {
                            placeholder
                        }
                    }
                    .padding(.top, 8)
                }
            }
        } footer: {
            HStack {
                Spacer()
                if !remaining.isEmpty {
                    Menu {
                        ForEach(remaining) { drink in
                            Button(drink.name) {
                                onSelect(drink)
                            }
                        }
                    } label: {
                        PrimaryLabel(title: "STAMP A DRINK", systemImage: "plus")
                    }
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 2) {
            Text(remaining.count == 1 ? "1 pour to go" : "\(remaining.count) pours to go")
            Text(entries.isEmpty ? "Stamp your first" : "Keep going")
        }
        .font(Theme.mono(11))
        .foregroundStyle(Theme.muted)
        .frame(width: 150, height: 96)
        .overlay {
            Rectangle()
                .strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .frame(maxWidth: .infinity, minHeight: 156)
    }
}
