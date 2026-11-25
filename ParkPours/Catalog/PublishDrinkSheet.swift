import SwiftUI

/// Curator only: tidy up a personal drink and publish it to the official
/// catalog, where every copy of the app will pick it up.
struct PublishDrinkSheet: View {
    let park: Park
    let drink: Drink
    let onPublished: () -> Void

    @EnvironmentObject private var store: PassportStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var venue: String
    @State private var area: String
    @State private var nonAlcoholic: Bool
    @State private var isSending = false
    @State private var errorMessage: String?

    init(park: Park, drink: Drink, onPublished: @escaping () -> Void) {
        self.park = park
        self.drink = drink
        self.onPublished = onPublished
        _name = State(initialValue: drink.name)
        _venue = State(initialValue: drink.venue)
        _area = State(initialValue: drink.area)
        _nonAlcoholic = State(initialValue: drink.nonAlcoholic)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Drink name", text: $name)
                    TextField("Bar or restaurant", text: $venue)
                    TextField("Land or area", text: $area)
                    Toggle("Non-alcoholic", isOn: $nonAlcoholic)
                } header: {
                    Text("Catalog entry for \(park.name)")
                } footer: {
                    Text("Publishing adds this drink to the official catalog for everyone. Your stamp, notes and photos stay private.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Publish to catalog")
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
                        Button("Publish", action: publish)
                            .disabled(trimmedName.isEmpty)
                    }
                }
            }
        }
    }

    private func publish() {
        guard let token = TokenStore.load() else {
            errorMessage = "No GitHub token is saved. Add one from the bug report form."
            return
        }
        // Same id as the personal drink, so the stamp carries over.
        var entry = drink
        entry.name = trimmedName
        entry.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.area = area.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.nonAlcoholic = nonAlcoholic
        entry.retired = false

        isSending = true
        errorMessage = nil
        Task {
            do {
                let published = try await CatalogPublisher(token: token).publish(entry, in: park)
                store.adopt(published)
                onPublished()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
