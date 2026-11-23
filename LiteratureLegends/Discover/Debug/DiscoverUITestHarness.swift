//
//  DiscoverUITestHarness.swift
//  LiteratureLegends · Discover
//
//  Restores a fixture session and exercises the production navigation without network access.
//

#if DEBUG
import SwiftUI

enum UITestLaunch {
    static let discoverArgument = "-UITestDiscover"
    static var isDiscover: Bool { ProcessInfo.processInfo.arguments.contains(discoverArgument) }
}

struct DiscoverUITestHarness: View {
    var body: some View {
        AuthRootView(
            authService: DiscoverTestAuthService(),
            searchService: MockPaperSearchService(delay: .milliseconds(200)),
            projectService: MockProjectService(delay: .zero)
        )
    }
}

private final class DiscoverTestAuthService: AuthServicing {
    private var user = AuthUser(id: "ui-test-user", email: "test@example.com", name: "Test User")

    func restoreSession() async throws -> AuthUser? { user }
    func login(email: String, password: String) async throws -> AuthUser { user }
    func register(name: String, email: String, password: String) async throws -> AuthUser { user }
    func updateName(_ name: String, userID: String) async throws { user.name = name }
    func logout() async throws {}
}
#endif
