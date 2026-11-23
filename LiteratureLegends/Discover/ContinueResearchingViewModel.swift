//
//  ContinueResearchingViewModel.swift
//  LiteratureLegends · Discover
//

import Foundation
import Observation

@MainActor
@Observable
final class ContinueResearchingViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([ResearchProject])
        case empty
        case error(ProjectServiceError)
    }

    static let projectLimit = Int.max

    private(set) var state: State = .idle

    private let ownerId: String
    private let service: any ProjectService
    private var loadTask: Task<Void, Never>?

    init(ownerId: String, service: any ProjectService) {
        self.ownerId = ownerId
        self.service = service
    }

    /// Loads once; safe to call from `.task` every time the view appears.
    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        if let loadTask { return await loadTask.value } // already loading
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        state = .loading
        do {
            let projects = try await service.recentProjects(ownerId: ownerId, limit: Self.projectLimit)
            state = projects.isEmpty ? .empty : .loaded(projects)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(ProjectServiceError(error))
        }
    }
}
