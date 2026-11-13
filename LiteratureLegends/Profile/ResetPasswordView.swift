import SwiftUI

struct ResetPasswordView: View {
    let email: String
    let sendResetLink: ((String) async throws -> Void)?
    @State private var isSending = false
    @State private var didSend = false
    @State private var failed = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Email", value: email)
                    .textSelection(.enabled)
            } header: {
                Text("Reset your password")
            } footer: {
                Text("We'll email a link to your account address so you can choose a new password.")
            }

            Section {
                Button {
                    Task { await requestReset() }
                } label: {
                    HStack {
                        Text(isSending ? "Sending…" : "Send reset link")
                        Spacer()
                        if isSending { ProgressView() }
                    }
                }
                .disabled(sendResetLink == nil || isSending || didSend)
            } footer: {
                if sendResetLink == nil {
                    Text("Password reset isn't available in this prototype yet. It will be enabled when account services are connected.")
                }
            }

            if didSend {
                Section {
                    Label("Check your email", systemImage: "envelope.badge")
                        .font(.headline)
                    Text("If an account is registered to this address, you'll receive a password reset link. Check your spam folder too.")
                }
            }
            if failed {
                Section {
                    Label("Couldn't request a reset link. Please try again.", systemImage: "exclamationmark.circle")
                }
            }
        }
        .navigationTitle("Reset password")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func requestReset() async {
        guard let sendResetLink, !isSending, !didSend else { return }
        isSending = true
        failed = false
        defer { isSending = false }
        do {
            try await sendResetLink(email)
            didSend = true
        } catch {
            failed = true
        }
    }
}
