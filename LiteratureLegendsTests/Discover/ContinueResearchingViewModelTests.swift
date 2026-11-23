//
//  ContinueResearchingViewModelTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

@MainActor
final class ContinueResearchingViewModelTests: XCTestCase {
    private func makeViewModel(_ behavior: MockProjectService.Behavior) -> ContinueResearchingViewModel {
        ContinueResearchingViewModel(ownerId: "u", service: MockProjectService(behavior: behavior, delay: .zero))
    }

    func testStartsIdle() {
        XCTAssertEqual(makeViewModel(.projects([])).state, .idle)
    }

    func testLoadedProjects() async {
        let viewModel = makeViewModel(.projects(MockProjectService.samples))
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.state, .loaded(MockProjectService.samples))
    }

    func testCapsAtFiveProjects() async {
        let many = (1...8).map { ResearchProject(id: "p\($0)", name: "P\($0)", updatedAt: nil) }
        let viewModel = makeViewModel(.projects(many))
        await viewModel.loadIfNeeded()
        guard case .loaded(let projects) = viewModel.state else { return XCTFail("Expected loaded") }
        XCTAssertEqual(projects.count, ContinueResearchingViewModel.projectLimit)
    }

    func testEmptyState() async {
        let viewModel = makeViewModel(.projects([]))
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.state, .empty)
    }

    func testErrorState() async {
        let viewModel = makeViewModel(.failure(.offline))
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.state, .error(.offline))
    }

    func testRetryAfterErrorLoadsAgain() async {
        let service = FlakyProjectService()
        let viewModel = ContinueResearchingViewModel(ownerId: "u", service: service)
        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.state, .error(.server(statusCode: 500)))

        await viewModel.retry()
        XCTAssertEqual(viewModel.state, .loaded([ResearchProject(id: "p1", name: "Recovered", updatedAt: nil)]))
    }

    func testLoadIfNeededDoesNotReloadAfterSuccess() async {
        let service = FlakyProjectService(failuresBeforeSuccess: 0)
        let viewModel = ContinueResearchingViewModel(ownerId: "u", service: service)
        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()
        let calls = await service.calls
        XCTAssertEqual(calls, 1)
    }
}

/// Fails a set number of times, then succeeds. Counts calls.
private actor FlakyProjectService: ProjectService {
    private var failuresLeft: Int
    private(set) var calls = 0

    init(failuresBeforeSuccess: Int = 1) {
        failuresLeft = failuresBeforeSuccess
    }

    func recentProjects(ownerId: String, limit: Int) async throws -> [ResearchProject] {
        calls += 1
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw ProjectServiceError.server(statusCode: 500)
        }
        return [ResearchProject(id: "p1", name: "Recovered", updatedAt: nil)]
    }

    func createProject(name: String, ownerId: String, paper: Paper) async throws -> ResearchProject {
        ResearchProject(id: "created", name: name, updatedAt: nil, ownerId: ownerId)
    }

    func add(paper: Paper, to project: ResearchProject, ownerId: String) async throws {}
}
