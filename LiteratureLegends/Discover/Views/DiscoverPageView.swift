//
//  DiscoverPageView.swift
//  LiteratureLegends · Discover
//
//  Discover screen from images/Wireframe2.jpeg: "Find your next idea", search, the scan
//  banner, and recent projects. AuthRootView supplies the navigation stack.
//

import SwiftUI

struct DiscoverPageView: View {
    let user: AuthUser
    private let searchService: (any PaperSearchService)?
    private let projectService: any ProjectService
    @State private var projects: ContinueResearchingViewModel

    /// - Parameter searchService: nil when no OpenAlex key is configured (shows setup steps instead of search).
    init(
        user: AuthUser,
        searchService: (any PaperSearchService)?,
        projectService: any ProjectService
    ) {
        self.user = user
        self.searchService = searchService
        self.projectService = projectService
        _projects = State(initialValue: ContinueResearchingViewModel(ownerId: user.id, service: projectService))
    }

    var body: some View {
        Group {
            if let searchService {
                DiscoverView(service: searchService, ownerId: user.id, projectService: projectService) { home }
            } else {
                // No OpenAlex key: keep the rest of the page usable and explain how to enable search.
                home
                    .navigationTitle("Find your next idea")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Find your next idea")
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
        .task { await projects.loadIfNeeded() }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if searchService == nil {
                    MissingAPIKeyView()
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                }
                ScanBannerView()
                ContinueResearchingView(viewModel: projects)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            await projects.retry()
        }
    }
}

/// Circle with the user's initials, like the "AB" badge in the wireframe.
struct InitialsBadge: View {
    let name: String

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.caption.weight(.semibold))
            .frame(width: 32, height: 32)
            .background(Circle().strokeBorder(.tint, lineWidth: 1.5))
    }
}

private let previewUser = AuthUser(id: "preview-user", email: "ada@example.edu", name: "Ada Byron")

#Preview("Home") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService())
    }
    .environmentObject(AuthManager())
}

#Preview("No projects") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService(behavior: .projects([])))
    }
    .environmentObject(AuthManager())
}

#Preview("Projects error") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService(behavior: .failure(.server(statusCode: 500))))
    }
    .environmentObject(AuthManager())
}

#Preview("No OpenAlex key") {
    NavigationStack {
        DiscoverPageView(user: previewUser, searchService: nil, projectService: MockProjectService())
    }
    .environmentObject(AuthManager())
}
