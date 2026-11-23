import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let user: AuthUser
    @State private var name: String
    @State private var isSaving = false
    @State private var saveError: String?

    init(user: AuthUser) {
        self.user = user
        _name = State(initialValue: user.name)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Personal information") {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("profileFullName")
                if !user.email.isEmpty {
                    LabeledContent("Email", value: user.email)
                }
            }
            if !user.email.isEmpty {
                Section("Security") {
                    NavigationLink {
                        ResetPasswordView(email: user.email, sendResetLink: nil)
                    } label: {
                        Label("Reset password", systemImage: "lock.rotation")
                    }
                }
            }
            if let saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(isSaving)
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .disabled(isSaving || trimmedName == user.name || (try? AuthValidation.validateName(trimmedName)) == nil)
            }
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            try await auth.updateName(trimmedName)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
