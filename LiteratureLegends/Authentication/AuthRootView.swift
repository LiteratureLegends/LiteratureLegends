import SwiftUI

struct AuthRootView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system
    @StateObject private var auth: AuthManager
    @State private var navigationPath = NavigationPath()
    private let searchService: (any PaperSearchService)?
    private let projectService: any ProjectService
    private let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

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
                NavigationStack(path: $navigationPath) {
                    DiscoverPageView(user: user, searchService: searchService, projectService: projectService)
                }
                .safeAreaInset(edge: .bottom) {
                    if !navigationPath.isEmpty {
                        Button {
                            navigationPath.removeLast(navigationPath.count)
                        } label: {
                            Label("Home", systemImage: "house.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
                .environmentObject(auth)
            } else {
                AuthEntryView(auth: auth)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(ProfileTheme.accent)
        .onAppear {
            guard !isRunningInPreview else { return }
            Task {
                await auth.restoreSession()
            }
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
