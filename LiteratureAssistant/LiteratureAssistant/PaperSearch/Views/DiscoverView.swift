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
            .navigationDestination(for: Paper.self) { paper in
                PaperDetailView(paper: paper, service: viewModel.service)
            }
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
                    NavigationLink(value: paper) {
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

@MainActor
private func previewDiscover(_ behavior: MockPaperSearchService.Behavior, query: String = "graph neural networks") -> DiscoverView {
    let viewModel = DiscoverViewModel(service: MockPaperSearchService(behavior: behavior))
    viewModel.query = query
    viewModel.submit()
    return DiscoverView(viewModel: viewModel)
}

#Preview("Idle") {
    DiscoverView(service: MockPaperSearchService())
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
