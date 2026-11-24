import SwiftUI

/// The stamping spread: entry application on the left, verdict on the right.
/// On a single screen the two pages stack and scroll.
struct StampEditor: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    let park: Park
    let drink: Drink
    private let isExisting: Bool
    private let maxRank: Int

    @State private var verdict: Verdict
    @State private var date: Date
    @State private var notes: String
    @State private var rank: Int
    @State private var stamped = false
    @FocusState private var notesFocused: Bool

    init(park: Park, drink: Drink, existing: Stamp?, existingRank: Int?, stampedCount: Int) {
        self.park = park
        self.drink = drink
        self.isExisting = existing != nil
        let top = max(existing == nil ? stampedCount + 1 : stampedCount, 1)
        self.maxRank = top
        _verdict = State(initialValue: existing?.verdict ?? .solidPour)
        _date = State(initialValue: existing?.date ?? Date())
        _notes = State(initialValue: existing?.notes ?? "")
        _rank = State(initialValue: min(existingRank ?? top, top))
    }

    private var previewStamp: Stamp {
        Stamp(verdict: verdict, date: date, notes: "")
    }

    var body: some View {
        GeometryReader { geo in
            let open = BookLayout.isOpen(geo.size)
            ZStack {
                PaperBackground()
                if open {
                    HStack(spacing: 0) {
                        formPage
                            .frame(width: geo.size.width / 2)
                        verdictPage
                            .frame(width: geo.size.width / 2)
                    }
                    SpineShadow()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            formPage
                            verdictPage
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
    }

    // MARK: Left page

    private var formPage: some View {
        PageScaffold(leading: "ENTRY APPLICATION", trailing: park.name.uppercased()) {
            Text(drink.name)
                .font(Theme.serif(28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(alignment: .top, spacing: 16) {
                field("VENUE", drink.venue.isEmpty ? "—" : drink.venue)
                field("AREA", drink.area.isEmpty ? "—" : drink.area)
            }

            VStack(alignment: .leading, spacing: 2) {
                fieldLabel("DATE OF ENTRY")
                DatePicker("Date of entry", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }

            notesField
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formats.mrz(["P", park.name, drink.name]))
                Text(Formats.mrz([drink.venue, drink.area, Formats.stamp(date)]))
            }
            .font(Theme.mono(11))
            .tracking(1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Theme.muted)
            .accessibilityHidden(true)
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                fieldLabel("TASTING NOTES")
                Spacer()
                if notesFocused {
                    Button("DONE") {
                        notesFocused = false
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
            .frame(minHeight: 44)
            SolidRule()
            TextEditor(text: $notes)
                .focused($notesFocused)
                .font(Theme.serif(15))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(11))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldLabel(label)
            Text(value)
                .font(Theme.mono(14, weight: .medium))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Right page

    private var verdictPage: some View {
        PageScaffold(leading: "VERDICT", trailing: "") {
            verdictGrid
            rankRow

            StampView(drink: drink, stamp: previewStamp)
                .scaleEffect(stamped ? 1.3 : 1.55)
                .opacity(stamped ? 1 : 0.35)
                .frame(maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
        } footer: {
            HStack {
                Button("CANCEL") {
                    dismiss()
                }
                .buttonStyle(LinkButtonStyle())
                if isExisting {
                    Button("REMOVE STAMP") {
                        store.removeStamp(for: drink, in: park)
                        dismiss()
                    }
                    .buttonStyle(LinkButtonStyle())
                    .padding(.leading, 12)
                }
                Spacer()
                Button(action: commit) {
                    PrimaryLabel(title: "STAMP IT")
                }
                .buttonStyle(.plain)
                .disabled(stamped)
            }
        }
    }

    private var verdictGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(Verdict.allCases) { option in
                VerdictButton(option: option, selected: option == verdict) {
                    verdict = option
                }
            }
        }
    }

    private var rankRow: some View {
        VStack(spacing: 6) {
            DottedRule()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    fieldLabel("RANK AT \(park.name.uppercased())")
                    Text("No. \(rank) of \(maxRank)")
                        .font(Theme.serif(17))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                stepButton("chevron.up", label: "Move up one place") {
                    rank = max(1, rank - 1)
                }
                stepButton("chevron.down", label: "Move down one place") {
                    rank = min(maxRank, rank + 1)
                }
            }
            DottedRule()
        }
    }

    private func stepButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .overlay {
                    Rectangle().strokeBorder(Theme.ink, lineWidth: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func commit() {
        let stamp = Stamp(
            verdict: verdict,
            date: date,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.saveStamp(stamp, for: drink, in: park, rank: rank)
        notesFocused = false
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
            stamped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

private struct VerdictButton: View {
    let option: Verdict
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(option.label)
                .font(Theme.stamp(15))
                .tracking(1.3)
                .foregroundStyle(selected ? Theme.paper : option.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(selected ? option.ink : Color.clear)
                .overlay {
                    Rectangle().strokeBorder(option.ink, lineWidth: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
