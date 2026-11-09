//
//  DiscoverView.swift
//  LiteratureAssistant · PaperSearch
//
//  Discover screen from images/Wireframe2.jpeg: "Find your next idea" + search.
//

import SwiftUI

struct DiscoverView: View {
    @State private var viewModel: DiscoverViewModel

    init(service: any PaperSearchService) {
        _viewModel = State(initialValue: DiscoverViewModel(service: service))
    }

    init(viewModel: DiscoverViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Find your next idea")
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Papers, topics, authors, DOI…"
            )
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) { viewModel.submit() }
            .onChange(of: viewModel.query) { viewModel.queryDidChange() }
            .onChange(of: viewModel.mode) { viewModel.modeDidChange() }
        }
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
        case .idle:
            ContentUnavailableView(
                "Search OpenAlex",
                systemImage: "magnifyingglass",
                description: Text("Find papers by keyword, topic, author name, or DOI.")
            )
        case .loading:
            ProgressView("Searching…")
        case .results:
            List(viewModel.papers) { paper in
                Text(paper.title)
            }
            .listStyle(.plain)
        case .empty(let query):
            ContentUnavailableView.search(text: query)
        case .error(let error):
            ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message))
        }
    }
}

#Preview("Results") {
    DiscoverView(service: MockPaperSearchService())
}

#Preview("Empty") {
    DiscoverView(service: MockPaperSearchService(behavior: .empty))
}

#Preview("Error") {
    DiscoverView(service: MockPaperSearchService(behavior: .failure(.rateLimited(retryAfterSeconds: 30))))
}
