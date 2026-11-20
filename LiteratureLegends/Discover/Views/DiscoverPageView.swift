//
//  DiscoverPageView.swift
//  LiteratureLegends · Discover
//
//  Discover screen from images/Wireframe2.jpeg: "Find your next idea", search, the scan
//  banner, and Continue Researching. Pushed from AuthenticatedHomeView until a tab bar exists,
//  so it has no NavigationStack of its own.
//

import SwiftUI

struct DiscoverPageView: View {
    let user: AuthUser
    private let searchService: (any PaperSearchService)?
    @State private var projects: ContinueResearchingViewModel

    /// - Parameter searchService: nil when no OpenAlex key is configured (shows setup steps instead of search).
    init(
        user: AuthUser,
        searchService: (any PaperSearchService)? = AppConfig.openAlexAPIKey.map { OpenAlexService(apiKey: $0) },
        projectService: any ProjectService = ParseProjectService()
    ) {
        self.user = user
        self.searchService = searchService
        _projects = State(initialValue: ContinueResearchingViewModel(ownerId: user.id, service: projectService))
    }

    var body: some View {
        Group {
            if let searchService {
                DiscoverView(service: searchService) { home }
            } else {
                // No OpenAlex key: keep the rest of the page usable and explain how to enable search.
                home
                    .navigationTitle("Find your next idea")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // TODO: Open Profile from here once the tab bar exists (wireframe "Profile" badge).
                InitialsBadge(name: user.name)
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
        .scrollDismissesKeyboard(.immediately)
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
            .accessibilityLabel("Signed in as \(name)")
    }
}

private let previewUser = AuthUser(id: "preview-user", email: "ada@example.edu", name: "Ada Byron")

#Preview("Home") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService())
    }
}

#Preview("No projects") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService(behavior: .projects([])))
    }
}

#Preview("Projects error") {
    NavigationStack {
        DiscoverPageView(user: previewUser,
                         searchService: MockPaperSearchService(),
                         projectService: MockProjectService(behavior: .failure(.server(statusCode: 500))))
    }
}

#Preview("No OpenAlex key") {
    NavigationStack {
        DiscoverPageView(user: previewUser, searchService: nil, projectService: MockProjectService())
    }
}
