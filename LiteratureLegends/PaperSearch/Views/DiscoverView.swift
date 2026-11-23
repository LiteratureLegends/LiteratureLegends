//
//  DiscoverView.swift
//  LiteratureLegends · PaperSearch
//
//  Search part of the Discover screen (images/Wireframe2.jpeg): search bar, mode picker,
//  results. The home content appears while the search field is empty.
//

import SwiftUI

struct DiscoverView<Home: View>: View {
    @State private var viewModel: DiscoverViewModel
    @State private var isSearchPresented = false
    private let home: Home

    init(service: any PaperSearchService, @ViewBuilder home: () -> Home) {
        _viewModel = State(initialValue: DiscoverViewModel(service: service))
        self.home = home()
    }

    init(viewModel: DiscoverViewModel, @ViewBuilder home: () -> Home) {
        _viewModel = State(initialValue: viewModel)
        self.home = home()
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchPresented || !viewModel.trimmedQuery.isEmpty {
                modePicker
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Find your next idea")
        .searchable(
            text: $viewModel.query,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Papers, topics, authors, DOI…"
        )
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onSubmit(of: .search) { viewModel.submit() }
        .onChange(of: viewModel.query) { viewModel.queryDidChange() }
        .onChange(of: viewModel.mode) { viewModel.modeDidChange() }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Search by", selection: $viewModel.mode) {
                ForEach(SearchMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.isDOIAutoDetected {
                Label("DOI detected, looking it up directly", systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle where viewModel.trimmedQuery.isEmpty:
            home
        case .idle:
            ContentUnavailableView(
                "Keep typing…",
                systemImage: "character.cursor.ibeam",
                description: Text("Type at least \(viewModel.minimumQueryLength) characters, or tap Search.")
            )
        case .loading:
            ProgressView("Searching…")
        case .results:
            resultsList
        case .empty(let query):
            ContentUnavailableView(
                "No papers found for “\(query)”",
                systemImage: "doc.text.magnifyingglass",
                description: Text(emptyHint)
            )
        case .error(let error):
            ContentUnavailableView {
                Label(error.title, systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle")
            } description: {
                Text(error.message)
            } actions: {
                if error.isRetryable {
                    Button("Retry") { viewModel.retry() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var resultsList: some View {
        List {
            Section {
                ForEach(viewModel.papers) { paper in
                    NavigationLink {
                        PaperDetailView(paper: paper, service: viewModel.service)
                    } label: {
                        PaperRowView(paper: paper)
                    }
                    .onAppear { viewModel.loadNextPageIfNeeded(currentPaper: paper) }
                }
            } header: {
                resultsHeader
            } footer: {
                pageFooter
            }
        }
        .listStyle(.plain)
    }

    private var resultsHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = viewModel.matchedEntityName {
                Text(viewModel.activeMode == .author ? "Showing works by \(name)" : "Showing works on \(name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)
            }
            Text("\(viewModel.totalCount.formatted()) \(viewModel.totalCount == 1 ? "result" : "results")")
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var pageFooter: some View {
        if viewModel.isLoadingNextPage {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if let error = viewModel.nextPageError {
            VStack(spacing: 8) {
                Text(error.message)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.loadNextPage() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else if !viewModel.hasMore, viewModel.papers.count > 5 {
            Text("End of results")
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    private var emptyHint: String {
        switch viewModel.activeMode {
        case .doi: "Check the DOI, or search by title keywords instead."
        case .author: "Check the spelling of the author's name, or try a keyword search."
        case .topic: "Try a broader topic, or switch to keyword search."
        default: "Try different keywords or another search mode."
        }
    }
}

/// The standalone idle screen, used when there is no Discover home content.
struct DiscoverSearchPrompt: View {
    var body: some View {
        ContentUnavailableView(
            "Search OpenAlex",
            systemImage: "magnifyingglass",
            description: Text("Find papers by keyword, topic, author name, or DOI.")
        )
    }
}

extension DiscoverView where Home == DiscoverSearchPrompt {
    init(service: any PaperSearchService) {
        self.init(service: service) { DiscoverSearchPrompt() }
    }

    init(viewModel: DiscoverViewModel) {
        self.init(viewModel: viewModel) { DiscoverSearchPrompt() }
    }
}

@MainActor
private func previewDiscover(_ behavior: MockPaperSearchService.Behavior, query: String = "graph neural networks") -> some View {
    let viewModel = DiscoverViewModel(service: MockPaperSearchService(behavior: behavior))
    viewModel.query = query
    viewModel.submit()
    return NavigationStack { DiscoverView(viewModel: viewModel) }
}

#Preview("Idle") {
    NavigationStack { DiscoverView(service: MockPaperSearchService()) }
}

#Preview("Results") {
    previewDiscover(.results)
}

#Preview("Empty") {
    previewDiscover(.empty, query: "zzqxv")
}

#Preview("Error") {
    previewDiscover(.failure(.rateLimited(retryAfterSeconds: 30)))
}

#Preview("Offline") {
    previewDiscover(.failure(.offline))
}
