
import SwiftUI

struct LoginView: View {
    @ObservedObject var auth: AuthManager
    let onCreateAccount: () -> Void

    @State private var email = ""
    @State private var password = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        Form {
            Section("Researcher account") {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            Section {
                Button {
                    focusedField = nil

                    Task {
                        await auth.login(
                            email: email,
                            password: password
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
                                ? "Logging in…"
                                : "Log in"
                        )
                        .fontWeight(.semibold)

                        Spacer()
                    }
                }
                .disabled(
                    auth.isWorking ||
                    email.isEmpty ||
                    password.isEmpty
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
                Button("Create an account") {
                    focusedField = nil
                    onCreateAccount()
                }
            } footer: {
                if !ParseConfiguration.isConfigured {
                    Text(
                        "Account login will be available once " +
                        "the team's Parse server is configured."
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
