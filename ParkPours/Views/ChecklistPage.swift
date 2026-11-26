import SwiftUI

/// Left page of a park spread: the checklist of drinks.
struct ChecklistPage: View {
    @EnvironmentObject private var store: PassportStore
    /// The park as it was when this page was built.
    let snapshot: Park
    let compact: Bool
    let onSelect: (Drink) -> Void
    let onIndex: () -> Void

    @State private var showAdd = false
    @State private var showScan = false
    @State private var newName = ""
    @State private var newVenue = ""

    /// The park as it is now. Read from the store so a drink added from this
    /// page shows up straight away, without waiting for the page to be rebuilt.
    private var park: Park {
        store.park(snapshot.id) ?? snapshot
    }

    private var stamped: Int {
        store.stampedCount(in: park)
    }

    private var fraction: Double {
        park.drinks.isEmpty ? 0 : Double(stamped) / Double(park.drinks.count)
    }

    var body: some View {
        PageScaffold(leading: "VISAS", trailing: park.resort.uppercased()) {
            heading

            ScrollView {
                VStack(spacing: 0) {
                    SolidRule()
                    ForEach(park.drinks) { drink in
                        Button {
                            onSelect(drink)
                        } label: {
                            DrinkRow(
                                drink: drink,
                                stamp: store.stamp(for: drink),
                                isPersonal: store.isCustom(drink)
                            )
                        }
                        .buttonStyle(.plain)
                        DottedRule()
                    }
                    addButton
                    scanButton
                }
            }
        } footer: {
            HStack {
                Button("ALL PARKS", action: onIndex)
                    .buttonStyle(LinkButtonStyle())
                Spacer()
                if compact {
                    Text("STAMPS ›")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .sheet(isPresented: $showScan) {
            MenuScanSheet(park: park)
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(Theme.cover)
        }
        .alert("Add a drink", isPresented: $showAdd) {
            TextField("Drink name", text: $newName)
            TextField("Where you got it", text: $newVenue)
            Button("Add") {
                store.addDrink(name: newName, venue: newVenue, to: park)
                newName = ""
                newVenue = ""
            }
            Button("Add as non-alcoholic") {
                store.addDrink(name: newName, venue: newVenue, nonAlcoholic: true, to: park)
                newName = ""
                newVenue = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
                newVenue = ""
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(park.name.uppercased())
                .font(Theme.serif(30, weight: .bold))
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                Text("\(stamped) of \(park.drinks.count) stamped")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize()
                ProgressRule(fraction: fraction)
            }
        }
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("ADD A DRINK")
                Spacer()
            }
        }
        .buttonStyle(LinkButtonStyle())
    }

    private var scanButton: some View {
        Button {
            showScan = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                Text("SCAN A DRINK")
                Spacer()
            }
        }
        .buttonStyle(LinkButtonStyle())
    }
}

private struct DrinkRow: View {
    let drink: Drink
    let stamp: Stamp?
    /// Added by this person, not from the official catalog.
    let isPersonal: Bool

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(verdict: stamp?.verdict)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(drink.name)
                        .font(Theme.serif(15))
                        .foregroundStyle(Theme.ink)
                    if drink.nonAlcoholic {
                        ZeroProofTag()
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 8)
            if let stamp {
                Text(stamp.verdict.label)
                    .font(Theme.stamp(11))
                    .tracking(0.9)
                    .foregroundStyle(stamp.verdict.ink)
            } else {
                Text("not yet")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if !drink.subtitle.isEmpty {
            parts.append(drink.subtitle)
        }
        if isPersonal {
            parts.append("added by you")
        }
        return parts.joined(separator: " · ")
    }
}

private struct CheckBox: View {
    let verdict: Verdict?

    var body: some View {
        ZStack {
            if let verdict {
                Rectangle()
                    .strokeBorder(verdict.ink, lineWidth: 1.5)
                Image(systemName: verdict == .denied ? "xmark" : "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(verdict.ink)
            } else {
                Rectangle()
                    .strokeBorder(Theme.muted, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
