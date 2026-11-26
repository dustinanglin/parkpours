import SwiftUI

/// Left page of the index spread: every park and its progress.
struct ParksPage: View {
    @EnvironmentObject private var store: PassportStore
    let compact: Bool
    let onOpen: (Park) -> Void
    let onClose: (() -> Void)?
    let onAddPark: () -> Void

    var body: some View {
        PageScaffold(leading: "PASSPORT", trailing: "\(store.totalStamps) STAMPED") {
            Text("Park Pours")
                .font(Theme.serif(30, weight: .bold))
                .foregroundStyle(Theme.ink)

            ScrollView {
                VStack(spacing: 0) {
                    SolidRule()
                    ForEach(store.parks) { park in
                        Button {
                            onOpen(park)
                        } label: {
                            ParkRow(park: park, stamped: store.stampedCount(in: park))
                        }
                        .buttonStyle(.plain)
                        DottedRule()
                    }
                    addButton
                }
            }
        } footer: {
            HStack {
                if let onClose {
                    Button("CLOSE BOOK", action: onClose)
                        .buttonStyle(LinkButtonStyle())
                }
                Spacer()
                if compact {
                    Text("RANKINGS ›")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAddPark) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("ADD A PARK")
                Spacer()
            }
        }
        .buttonStyle(LinkButtonStyle())
    }
}

private struct ParkRow: View {
    let park: Park
    let stamped: Int

    private var fraction: Double {
        park.drinks.isEmpty ? 0 : Double(stamped) / Double(park.drinks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(park.name)
                    .font(Theme.serif(18))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(park.drinks.isEmpty ? "no drinks yet" : "\(stamped) of \(park.drinks.count)")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
            ProgressRule(fraction: fraction)
        }
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}
