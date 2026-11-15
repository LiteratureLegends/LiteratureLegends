import SwiftUI

struct EditProfileView: View {
    @ObservedObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var userName: String
    @State private var usernameNotice: String?

    init(store: ProfileStore) {
        self.store = store
        _firstName = State(initialValue: store.profile.firstName)
        _lastName = State(initialValue: store.profile.lastName)
        _userName = State(initialValue: store.profile.userName)
    }

    private var cleanFirstName: String { firstName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanLastName: String { lastName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var cleanUserName: String { userName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !cleanFirstName.isEmpty && !cleanLastName.isEmpty && UsernameRules.isValid(userName)
    }

    var body: some View {
        Form {
            Section("Personal information") {
                LabeledContent("First name") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Last name") {
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
            }
            Section {
                TextField("Username", text: $userName)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: userName) { _, newValue in
                        let filtered = UsernameRules.filtered(newValue)
                        if filtered != newValue {
                            usernameNotice = "Only letters, numbers, and underscores are allowed, up to 20 characters."
                            userName = filtered
                        }
                    }
            } header: {
                Text("Username")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(UsernameRules.guidance)
                    if let usernameNotice {
                        Label(usernameNotice, systemImage: "info.circle")
                    }
                    if userName.count < UsernameRules.minimumLength {
                        Label("Enter at least 3 characters to save.", systemImage: "exclamationmark.circle")
                    }
                }
            }
            Section {
                LabeledContent("Email", value: store.profile.email)
            } footer: {
                Text("Email changes will be managed through your account settings when authentication is connected.")
            }
            Section("Security") {
                NavigationLink {
                    ResetPasswordView(email: store.profile.email, sendResetLink: store.sendPasswordReset)
                } label: {
                    Label("Reset password", systemImage: "lock.rotation")
                        .foregroundStyle(.tint)
                }
            }
            Section {
                Text("Changes apply to this sample profile only and reset when the app closes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard canSave else { return }
                    store.profile.firstName = cleanFirstName
                    store.profile.lastName = cleanLastName
                    store.profile.userName = cleanUserName
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }
}
