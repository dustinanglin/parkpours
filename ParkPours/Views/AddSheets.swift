import SwiftUI

/// A sheet opened from the book. These are presented by the root view, not
/// by the page that asked for them, so nothing that rebuilds a page while
/// the keyboard is up can lose what was typed.
enum RootSheet: Identifiable {
    case addDrink(Park)
    case scanDrink(Park)
    case addPark

    var id: String {
        switch self {
        case .addDrink(let park): return "add-drink-\(park.id)"
        case .scanDrink(let park): return "scan-drink-\(park.id)"
        case .addPark: return "add-park"
        }
    }
}

/// Type a drink in by hand. It is added to the park as a personal drink.
struct AddDrinkSheet: View {
    let park: Park

    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var venue = ""
    @State private var details = ""
    @State private var nonAlcoholic = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Drink name", text: $name)
                        .focused($nameFocused)
                    TextField("Bar or restaurant (optional)", text: $venue)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...6)
                    Toggle("Non-alcoholic", isOn: $nonAlcoholic)
                } header: {
                    Text("Adding to \(park.name)")
                } footer: {
                    Text("The drink is yours only; it is not part of the official catalog.")
                }
            }
            .navigationTitle("Add a drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addDrink(
                            name: trimmedName,
                            venue: venue,
                            details: details,
                            nonAlcoholic: nonAlcoholic,
                            to: park
                        )
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                nameFocused = true
            }
        }
    }
}

/// Add a park of your own.
struct AddParkSheet: View {
    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Park name", text: $name)
                        .focused($nameFocused)
                } footer: {
                    Text("The park is yours only. Add its drinks from its checklist.")
                }
            }
            .navigationTitle("Add a park")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addPark(name: trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                nameFocused = true
            }
        }
    }
}
