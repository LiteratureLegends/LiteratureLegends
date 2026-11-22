import SwiftUI

struct AuthRootView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @StateObject private var auth: AuthManager
    private let searchService: (any PaperSearchService)?
    private let projectService: any ProjectService

    init(
        authService: any AuthServicing = ParseAuthService(),
        searchService: (any PaperSearchService)? = AppConfig.openAlexAPIKey.map { OpenAlexService(apiKey: $0) },
        projectService: any ProjectService = ParseProjectService()
    ) {
        _auth = StateObject(wrappedValue: AuthManager(service: authService))
        self.searchService = searchService
        self.projectService = projectService
    }

    var body: some View {
        Group {
            if auth.isCheckingSession {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking your account…")
                        .foregroundStyle(.secondary)
                }
            } else if let user = auth.currentUser {
                NavigationStack {
                    DiscoverPageView(user: user, searchService: searchService, projectService: projectService)
                }
                .environmentObject(auth)
            } else {
                AuthEntryView(auth: auth)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(ProfileTheme.accent)
        .task {
            await auth.restoreSession()
        }
    }
}

// Login and registration navigation
private struct AuthEntryView: View {
    @ObservedObject var auth: AuthManager
    @State private var showingRegistration = false

    var body: some View {
        NavigationStack {
            Group {
                if showingRegistration {
                    RegisterView(auth: auth) {
                        auth.clearError()
                        showingRegistration = false
                    }
                } else {
                    LoginView(auth: auth) {
                        auth.clearError()
                        showingRegistration = true
                    }
                }
            }
            .navigationTitle(
                showingRegistration ? "Create account" : "Log in"
            )
        }
    }
}
