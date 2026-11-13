
import SwiftUI

struct RegisterView: View {
    @ObservedObject var auth: AuthManager
    let onLogin: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        Form {
            Section("Account information") {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }

            Section("Password") {
                SecureField(
                    "Password (8+ characters)",
                    text: $password
                )
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }

                SecureField(
                    "Confirm password",
                    text: $confirmPassword
                )
                .textContentType(.newPassword)
                .focused(
                    $focusedField,
                    equals: .confirmPassword
                )
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
            }

            Section {
                Button {
                    focusedField = nil

                    Task {
                        await auth.register(
                            name: name,
                            email: email,
                            password: password,
                            confirm: confirmPassword
                        )
                    }
                } label: {
                    HStack {
                        Spacer()

                        if auth.isWorking {
                            ProgressView()
                        }

                        Text(
                            auth.isWorking
                                ? "Creating account…"
                                : "Create account"
                        )
                        .fontWeight(.semibold)

                        Spacer()
                    }
                }
                .disabled(
                    auth.isWorking ||
                    name.isEmpty ||
                    email.isEmpty ||
                    password.isEmpty ||
                    confirmPassword.isEmpty
                )
            }

            if let error = auth.errorMessage {
                Section {
                    Label(
                        error,
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.red)
                }
            }

            Section {
                Button(
                    "Already have an account? Log in"
                ) {
                    focusedField = nil
                    onLogin()
                }
            } footer: {
                if !ParseConfiguration.isConfigured {
                    Text(
                        "Account creation will be available " +
                        "once the team's Parse server is configured."
                    )
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
}
