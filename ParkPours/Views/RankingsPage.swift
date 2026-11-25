import SwiftUI

/// Right page of the index spread: every stamped drink, grouped by verdict.
struct RankingsPage: View {
    @EnvironmentObject private var store: PassportStore
    let onSelect: (Park, Drink) -> Void

    var body: some View {
        PageScaffold(leading: "RANKINGS", trailing: "ALL PARKS") {
            Text("The good ones")
                .font(Theme.serif(26, weight: .bold))
                .foregroundStyle(Theme.ink)

            if store.totalStamps == 0 {
                Text("No stamps yet. Open a park and stamp your first pour.")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Verdict.allCases) { verdict in
                            section(verdict)
                        }
                    }
                }
            }
        } footer: {
            EmptyView()
        }
    }

    @ViewBuilder
    private func section(_ verdict: Verdict) -> some View {
        let entries = store.allStamped(with: verdict)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(verdict.label)
                    .font(Theme.stamp(13))
                    .tracking(1.2)
                    .foregroundStyle(verdict.ink)
                    .padding(.bottom, 6)
                Rectangle()
                    .fill(verdict.ink)
                    .frame(height: 1.5)
                ForEach(entries) { entry in
                    Button {
                        onSelect(entry.park, entry.drink)
                    } label: {
                        RankingRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    DottedRule()
                }
            }
        }
    }
}

private struct RankingRow: View {
    let entry: StampedEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.drink.name)
                    .font(Theme.serif(15))
                    .foregroundStyle(Theme.ink)
                Text(entry.park.name)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            Text("No. \(entry.rank)")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.muted)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}
