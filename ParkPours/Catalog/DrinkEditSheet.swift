import SwiftUI

/// What saving the sheet does.
enum DrinkEditMode: String, Identifiable {
    var id: String { rawValue }

    /// Change a drink this person added. Stays on the phone.
    case personal
    /// Curator: publish a personal drink to the official catalog.
    case publish
    /// Curator: change a drink that is already in the official catalog.
    case catalog
}

enum DrinkEditResult {
    case saved
    case deleted
}

/// Edit a drink's name, venue, area and non-alcoholic tag.
struct DrinkEditSheet: View {
    let park: Park
    let drink: Drink
    let mode: DrinkEditMode
    let onDone: (DrinkEditResult) -> Void

    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var venue: String
    @State private var area: String
    @State private var details: String
    @State private var nonAlcoholic: Bool
    @State private var retired: Bool
    @State private var isSending = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    init(park: Park, drink: Drink, mode: DrinkEditMode, onDone: @escaping (DrinkEditResult) -> Void) {
        self.park = park
        self.drink = drink
        self.mode = mode
        self.onDone = onDone
        _name = State(initialValue: drink.name)
        _venue = State(initialValue: drink.venue)
        _area = State(initialValue: drink.area)
        _details = State(initialValue: drink.details)
        _nonAlcoholic = State(initialValue: drink.nonAlcoholic)
        _retired = State(initialValue: drink.retired)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch mode {
        case .personal: return "Edit drink"
        case .publish: return "Publish to catalog"
        case .catalog: return "Edit catalog entry"
        }
    }

    private var saveLabel: String {
        mode == .personal ? "Save" : "Publish"
    }

    private var explanation: String {
        switch mode {
        case .personal:
            return "This drink is yours only. Changes stay on this phone."
        case .publish:
            return "Publishing adds this drink to the official catalog for everyone. Your stamp, notes and photos stay private."
        case .catalog:
            return "Publishing changes this drink in the official catalog for everyone."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Drink name", text: $name)
                    TextField("Bar or restaurant", text: $venue)
                    TextField("Land or area", text: $area)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                        .lineLimit(2...6)
                    Toggle("Non-alcoholic", isOn: $nonAlcoholic)
                } header: {
                    Text(park.name)
                } footer: {
                    Text(explanation)
                }

                if mode == .catalog {
                    Section {
                        Toggle("Retired", isOn: $retired)
                    } footer: {
                        Text("A retired drink is no longer served. It leaves the checklist but stays on any passport that already stamped it.")
                    }
                }

                if mode == .personal {
                    Section {
                        Button("Delete this drink", role: .destructive) {
                            confirmDelete = true
                        }
                    } footer: {
                        Text("Also removes its stamp, notes and photos.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button(saveLabel, action: save)
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
            .confirmationDialog(
                "Delete \(drink.name)?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete drink", role: .destructive) {
                    store.deleteDrink(drink, in: park)
                    onDone(.deleted)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its stamp, notes and photos are removed too. This cannot be undone.")
            }
        }
    }

    private func save() {
        // Same id throughout, so a stamp always stays with its drink.
        var entry = drink
        entry.name = trimmedName
        entry.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.area = area.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.nonAlcoholic = nonAlcoholic
        entry.retired = mode == .catalog ? retired : false

        if mode == .personal {
            store.updateDrink(entry, in: park)
            onDone(.saved)
            dismiss()
            return
        }

        guard let token = TokenStore.load() else {
            errorMessage = "No GitHub token is saved. Add one from the bug report form."
            return
        }
        isSending = true
        errorMessage = nil
        Task {
            do {
                let published = try await CatalogPublisher(token: token).publish(entry, in: park)
                store.adopt(published)
                onDone(.saved)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
