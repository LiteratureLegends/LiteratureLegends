//
//  DiscoverUITestHarness.swift
//  LiteratureLegends · Discover
//
//  DEBUG only. Launched with `-UITestDiscover` by LiteratureLegendsUITests: skips login and uses
//  mock services, but keeps the real navigation shape of AuthenticatedHomeView (AuthRootView.swift):
//  a NavigationStack with a List and a view-based NavigationLink("Discover").
//

#if DEBUG
import SwiftUI

enum UITestLaunch {
    static let discoverArgument = "-UITestDiscover"
    static var isDiscover: Bool { ProcessInfo.processInfo.arguments.contains(discoverArgument) }
}

struct DiscoverUITestHarness: View {
    private let user = AuthUser(id: "ui-test-user", email: "test@example.com", name: "Test User")

    var body: some View {
        NavigationStack {
            List {
                Section("Current development build") {
                    NavigationLink("Discover") {
                        DiscoverPageView(
                            user: user,
                            searchService: MockPaperSearchService(delay: .milliseconds(200)),
                            projectService: MockProjectService(delay: .zero)
                        )
                    }
                }
            }
            .navigationTitle("Home")
        }
    }
}
#endif
