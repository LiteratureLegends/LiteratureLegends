import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isCheckingSession = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private let service: AuthServicing
    private let isRunningInPreview: Bool

    init(service: AuthServicing = ParseAuthService()) {
        self.service = service
        self.isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isRunningInPreview {
            // Prevent Canvas from waiting on live auth/session recovery.
            isCheckingSession = false
        }
    }

    func restoreSession() async {
        guard !isRunningInPreview else { return }
        guard isCheckingSession else { return }
        defer { isCheckingSession = false }
        do {
            currentUser = try await service.restoreSession()
        } catch {
            // Don't discard a stored token for temporary network failures.
            errorMessage = "Couldn't check your previous session: \(error.localizedDescription)"
        }
    }

    func register(name: String, email: String, password: String, confirm: String) async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            guard password == confirm else { throw AuthFailure.passwordsDoNotMatch }
            currentUser = try await service.register(name: name, email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            currentUser = try await service.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.logout()
            currentUser = nil
        } catch {
            errorMessage = "Couldn't log out: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
