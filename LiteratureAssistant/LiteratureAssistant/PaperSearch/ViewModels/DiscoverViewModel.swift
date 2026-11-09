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

    // MARK: Configuration

    let minimumQueryLength = 3
    let debounceInterval: Duration

    private let service: any PaperSearchService
    private var searchTask: Task<Void, Never>?
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

    /// Awaits the in-flight search (used by tests and previews).
    func waitForCurrentSearch() async {
        await searchTask?.value
    }

    // MARK: Private

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        generation += 1
    }

    private func reset() {
        state = .idle
        papers = []
        totalCount = 0
        matchedEntityName = nil
        activeQuery = nil
        activeMode = nil
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
        papers = page.papers
        totalCount = page.totalCount
        matchedEntityName = page.matchedEntityName
        state = page.papers.isEmpty ? .empty(query: query) : .results
    }
}
