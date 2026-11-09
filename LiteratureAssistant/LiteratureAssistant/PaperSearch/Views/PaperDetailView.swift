//
//  PaperDetailView.swift
//  LiteratureAssistant · PaperSearch
//
//  Drill-down for one search result (#15). "Save to project" is intentionally not here yet.
//

import SwiftUI

struct PaperDetailView: View {
    @State private var viewModel: PaperDetailViewModel

    init(paper: Paper, service: any PaperSearchService) {
        _viewModel = State(initialValue: PaperDetailViewModel(paper: paper, service: service))
    }

    private var paper: Paper { viewModel.paper }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(paper.title)
                    .font(.title2.bold())
                    .textSelection(.enabled)

                authorsSection
                metadataSection
                abstractSection

                if let url = paper.openURL {
                    Link(destination: url) {
                        Label("Open source", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Paper")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadDetailsIfNeeded() }
    }

    private var authorsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(paper.authors.count == 1 ? "Author" : "Authors (\(paper.authors.count))")
            Text(paper.authors.isEmpty ? "Unknown authors" : paper.authors.joined(separator: ", "))
                .foregroundStyle(paper.authors.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    private var metadataSection: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            metadataRow("Venue", value: paper.venue)
            metadataRow(paper.publicationDate == nil ? "Year" : "Published", value: paper.displayDate)
            metadataRow("Citations", value: paper.citationCount.map { $0.formatted() })
            GridRow {
                Text("DOI").foregroundStyle(.secondary)
                if let doi = paper.doi, let url = paper.doiURL {
                    Link(doi, destination: url)
                        .lineLimit(2)
                } else {
                    Text("Not available").foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
    }

    private func metadataRow(_ label: String, value: String?) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value ?? "Not available")
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var abstractSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Abstract")
            if let abstract = paper.abstract {
                Text(abstract)
                    .textSelection(.enabled)
            } else if viewModel.isLoadingDetails {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading full record…").foregroundStyle(.secondary)
                }
            } else {
                Text("Abstract not available")
                    .foregroundStyle(.secondary)
                    .italic()
            }

            if let error = viewModel.detailError {
                HStack(alignment: .firstTextBaseline) {
                    Label(error.message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if error.isRetryable {
                        Button("Retry") { Task { await viewModel.retry() } }
                            .font(.footnote)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }
}

#Preview("Complete") {
    NavigationStack {
        PaperDetailView(paper: MockPaperSearchService.sample, service: MockPaperSearchService())
    }
}

#Preview("Fills in missing fields") {
    NavigationStack {
        PaperDetailView(
            paper: Paper(externalApiId: "W2741809807", title: "The state of OA", authors: ["Heather Piwowar"], sourceUrl: "https://openalex.org/W2741809807"),
            service: MockPaperSearchService(delay: .seconds(1))
        )
    }
}

#Preview("Details unavailable") {
    NavigationStack {
        PaperDetailView(
            paper: Paper(externalApiId: "W1", title: "A paper with little metadata", sourceUrl: "https://openalex.org/W1"),
            service: MockPaperSearchService(behavior: .failure(.offline))
        )
    }
}
