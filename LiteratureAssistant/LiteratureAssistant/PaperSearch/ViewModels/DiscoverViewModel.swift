//
//  DiscoverViewModel.swift
//  LiteratureAssistant · PaperSearch
//

import Foundation
import Observation

@MainActor
@Observable
final class DiscoverViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results
        case empty(query: String)
        case error(PaperSearchError)
    }

    // MARK: Inputs (bound to the UI)

    var query = ""
    var mode: SearchMode = .keyword

    // MARK: Outputs

    private(set) var state: State = .idle
    private(set) var papers: [Paper] = []
    private(set) var totalCount = 0
    /// Author or topic the query resolved to ("Showing works by …").
    private(set) var matchedEntityName: String?
    /// The query and mode of the results on screen.
    private(set) var activeQuery: String?
    private(set) var activeMode: SearchMode?
    /// More pages are available for the current results.
    private(set) var hasMore = false
    private(set) var isLoadingNextPage = false
    /// Set when loading a further page failed; the results already shown stay visible.
    private(set) var nextPageError: PaperSearchError?

    // MARK: Configuration

    let minimumQueryLength = 3
    let debounceInterval: Duration

    /// Shared with the detail screen so it uses the same backend.
    let service: any PaperSearchService
    private var searchTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?
    private var currentPage = 1
    /// Start loading the next page when a row this close to the end appears.
    private let prefetchThreshold = 5
    /// Bumped for every new search so late responses from older searches are ignored.
    private var generation = 0

    init(service: any PaperSearchService, debounceInterval: Duration = .milliseconds(400)) {
        self.service = service
        self.debounceInterval = debounceInterval
    }

    /// The trimmed query text.
    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The mode that will actually be used (DOIs are detected automatically).
    var effectiveMode: SearchMode { SearchMode.effectiveMode(for: trimmedQuery, selected: mode) }

    var isDOIAutoDetected: Bool { mode != .doi && effectiveMode == .doi }

    // MARK: Intents

    /// Call on every keystroke. Searches after `debounceInterval` once the query has
    /// at least `minimumQueryLength` characters; clearing the field returns to idle.
    func queryDidChange() {
        let text = trimmedQuery
        if text.isEmpty {
            cancelSearch()
            reset()
            return
        }
        guard text.count >= minimumQueryLength else {
            // Too short to search while typing: drop any pending debounce.
            searchTask?.cancel()
            return
        }
        if text == activeQuery, effectiveMode == activeMode, state != .loading { return }
        startSearch(query: text, mode: effectiveMode, delay: debounceInterval)
    }

    /// Called when the user changes the segmented picker.
    func modeDidChange() {
        let text = trimmedQuery
        guard !text.isEmpty else { return }
        startSearch(query: text, mode: effectiveMode, delay: .zero)
    }

    /// Return key / search button: search right away (any non-empty length).
    func submit() {
        let text = trimmedQuery
        guard !text.isEmpty else { return }
        startSearch(query: text, mode: effectiveMode, delay: .zero)
    }

    func retry() {
        if let activeQuery, let activeMode {
            startSearch(query: activeQuery, mode: activeMode, delay: .zero)
        } else {
            submit()
        }
    }

    /// Infinite scroll: call when a row appears; loads the next page near the end of the list.
    func loadNextPageIfNeeded(currentPaper paper: Paper) {
        guard let index = papers.firstIndex(where: { $0.id == paper.id }),
              index >= papers.count - prefetchThreshold,
              nextPageError == nil
        else { return }
        loadNextPage()
    }

    /// Loads the next page of the current results (also used by the footer's Retry button).
    func loadNextPage() {
        guard state == .results, hasMore, !isLoadingNextPage,
              let query = activeQuery, let mode = activeMode
        else { return }
        let generation = self.generation
        let page = currentPage + 1
        isLoadingNextPage = true
        nextPageError = nil
        nextPageTask = Task { [weak self] in
            await self?.performNextPage(query: query, mode: mode, page: page, generation: generation)
        }
    }

    /// Awaits the in-flight search (used by tests and previews).
    func waitForCurrentSearch() async {
        await searchTask?.value
    }

    /// Awaits the in-flight next-page load (used by tests).
    func waitForNextPage() async {
        await nextPageTask?.value
    }

    // MARK: Private

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        nextPageTask?.cancel()
        nextPageTask = nil
        isLoadingNextPage = false
        generation += 1
    }

    private func reset() {
        state = .idle
        papers = []
        totalCount = 0
        matchedEntityName = nil
        activeQuery = nil
        activeMode = nil
        hasMore = false
        nextPageError = nil
        currentPage = 1
    }

    private func startSearch(query: String, mode: SearchMode, delay: Duration) {
        cancelSearch()
        let generation = self.generation
        searchTask = Task { [weak self] in
            if delay > .zero {
                do { try await Task.sleep(for: delay) } catch { return }
            }
            await self?.performSearch(query: query, mode: mode, generation: generation)
        }
    }

    private func performSearch(query: String, mode: SearchMode, generation: Int) async {
        guard generation == self.generation, !Task.isCancelled else { return }
        state = .loading
        activeQuery = query
        activeMode = mode
        papers = []
        totalCount = 0
        matchedEntityName = nil
        hasMore = false
        nextPageError = nil
        currentPage = 1

        do {
            let page = try await service.searchPapers(query: query, mode: mode, page: 1)
            guard generation == self.generation, !Task.isCancelled else { return }
            apply(page, query: query)
        } catch {
            guard generation == self.generation, !Task.isCancelled, !(error is CancellationError) else { return }
            state = .error(PaperSearchError(error))
        }
    }

    private func apply(_ page: PaperSearchPage, query: String) {
        papers = Self.removingDuplicates(page.papers, existing: [])
        totalCount = page.totalCount
        matchedEntityName = page.matchedEntityName
        hasMore = page.hasMore
        currentPage = page.page
        state = papers.isEmpty ? .empty(query: query) : .results
    }

    private func performNextPage(query: String, mode: SearchMode, page: Int, generation: Int) async {
        defer { if generation == self.generation { isLoadingNextPage = false } }
        do {
            let result = try await service.searchPapers(query: query, mode: mode, page: page)
            guard generation == self.generation, !Task.isCancelled else { return }
            // Relevance-ranked pages can overlap slightly; List needs unique IDs.
            papers += Self.removingDuplicates(result.papers, existing: Set(papers.map(\.id)))
            currentPage = page
            hasMore = result.hasMore && !result.papers.isEmpty
        } catch {
            guard generation == self.generation, !Task.isCancelled, !(error is CancellationError) else { return }
            nextPageError = PaperSearchError(error)
        }
    }

    private static func removingDuplicates(_ incoming: [Paper], existing: Set<String>) -> [Paper] {
        var seen = existing
        return incoming.filter { seen.insert($0.id).inserted }
    }
}
