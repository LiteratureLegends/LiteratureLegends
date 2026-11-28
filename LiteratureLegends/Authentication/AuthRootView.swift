
import SwiftUI

struct AuthRootView: View {
    @StateObject private var auth: AuthManager
    private let searchService: (any PaperSearchService)?
    private let projectService: (any ProjectService)?
    private let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(
        authService: AuthServicing = ParseAuthService(),
        searchService: (any PaperSearchService)? = nil,
        projectService: (any ProjectService)? = nil
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
                AuthenticatedHomeView(
                    auth: auth,
                    user: user,
                    searchService: searchService,
                    projectService: projectService
                )
            } else {
                AuthEntryView(auth: auth)
            }
        }
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

// Screen displayed after successful login
private struct AuthenticatedHomeView: View {
    @ObservedObject var auth: AuthManager
    let user: AuthUser
    private let searchService: (any PaperSearchService)?
    private let projectService: any ProjectService

    init(
        auth: AuthManager,
        user: AuthUser,
        searchService: (any PaperSearchService)? = nil,
        projectService: (any ProjectService)? = nil
    ) {
        self.auth = auth
        self.user = user
        if let searchService {
            self.searchService = searchService
        } else if let apiKey = AppConfig.openAlexAPIKey {
            self.searchService = OpenAlexService(apiKey: apiKey)
        } else {
            self.searchService = nil
        }
        self.projectService = projectService ?? ParseProjectService()
    }

    var body: some View {
        TabView {
            NavigationStack {
                DiscoverPageView(
                    user: user,
                    searchService: searchService,
                    projectService: projectService
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                SearchTabView(
                    user: user,
                    searchService: searchService,
                    projectService: projectService
                )
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ProjectsTabView(user: user, projectService: projectService)
            }
            .tabItem {
                Label("Projects", systemImage: "folder")
            }
        }
        // ProfileView (opened from the badge) reads AuthManager for log out.
        .environmentObject(auth)
    }
}

/// Matches the Home page chrome: inline serif title and the profile badge.
private struct TabChrome: ViewModifier {
    let title: String
    let user: AuthUser

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        InitialsBadge(name: user.displayName)
                    }
                    .accessibilityLabel("Open profile")
                }
            }
    }
}

private struct SearchTabView: View {
    let user: AuthUser
    let searchService: (any PaperSearchService)?
    let projectService: any ProjectService

    var body: some View {
        Group {
            if let searchService {
                DiscoverView(
                    service: searchService,
                    ownerId: user.id,
                    projectService: projectService
                ) {
                    DiscoverSearchPrompt()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemGroupedBackground))
                }
            } else {
                MissingAPIKeyView()
                    .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .modifier(TabChrome(title: "Search", user: user))
    }
}

private struct ProjectsTabView: View {
    let user: AuthUser
    let projectService: any ProjectService
    @State private var projects: ContinueResearchingViewModel

    init(user: AuthUser, projectService: any ProjectService) {
        self.user = user
        self.projectService = projectService
        _projects = State(initialValue: ContinueResearchingViewModel(ownerId: user.id, service: projectService))
    }

    var body: some View {
        ScrollView {
            ContinueResearchingView(viewModel: projects)
                .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .modifier(TabChrome(title: "Projects", user: user))
        .task { await projects.loadIfNeeded() }
        .refreshable { await projects.retry() }
    }
}
