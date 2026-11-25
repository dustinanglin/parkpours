import SwiftUI
import UIKit

/// The bug report form. Files a GitHub issue, with the screenshot if wanted.
struct FeedbackSheet: View {
    let draft: FeedbackDraft

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var includeScreenshot = true
    @State private var token = TokenStore.load() ?? ""
    @State private var tokenEntry = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var filed: FiledIssue?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedTitle.isEmpty && !token.isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                if let filed {
                    doneSection(filed)
                } else {
                    reportSection
                    screenshotSection
                    contextSection
                    tokenSection
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Report a bug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(filed == nil ? "Cancel" : "Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else if filed == nil {
                        Button("File", action: submit)
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var reportSection: some View {
        Section("What happened") {
            TextField("Short title", text: $title)
            TextField("Details (optional)", text: $details, axis: .vertical)
                .lineLimit(4...10)
        }
    }

    @ViewBuilder
    private var screenshotSection: some View {
        if let image = draft.screenshot {
            Section {
                Toggle("Include screenshot", isOn: $includeScreenshot)
                if includeScreenshot {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Rectangle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                        }
                }
            } footer: {
                Text("The repo is public, so the screenshot and the issue are visible to anyone.")
            }
        }
    }

    private var contextSection: some View {
        Section("Sent with the report") {
            ForEach(draft.context, id: \.self) { line in
                Text(line)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tokenSection: some View {
        if token.isEmpty {
            Section {
                SecureField("Paste GitHub token", text: $tokenEntry)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save token", action: saveToken)
                    .disabled(tokenEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("One-time setup")
            } footer: {
                Text("Use a fine-grained token limited to \(FeedbackConfig.owner)/\(FeedbackConfig.repo), with Issues and Contents set to read and write. It is stored in this device's Keychain.")
            }
        } else {
            Section {
                Button("Remove saved GitHub token", role: .destructive) {
                    TokenStore.clear()
                    token = ""
                }
            }
        }
    }

    private func doneSection(_ filed: FiledIssue) -> some View {
        Section {
            Label("Filed as issue #\(filed.number)", systemImage: "checkmark.circle.fill")
            if let url = filed.url {
                Link("Open on GitHub", destination: url)
            }
        }
    }

    // MARK: Actions

    private func saveToken() {
        let cleaned = tokenEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if TokenStore.save(cleaned) {
            token = cleaned
            tokenEntry = ""
            errorMessage = nil
        } else {
            errorMessage = "Could not save the token to the Keychain."
        }
    }

    private func submit() {
        let client = GitHubIssueClient(token: token)
        let issueTitle = trimmedTitle
        let issueDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let jpeg = includeScreenshot ? draft.screenshot?.jpegData(compressionQuality: 0.8) : nil
        let context = draft.context

        isSending = true
        errorMessage = nil
        Task {
            do {
                filed = try await client.fileIssue(
                    title: issueTitle,
                    details: issueDetails,
                    screenshotJPEG: jpeg,
                    context: context
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}
