//
//  MockProjectService.swift
//  LiteratureLegends · Discover
//
//  In-memory ProjectService for SwiftUI previews and tests. No networking.
//

import Foundation

struct MockProjectService: ProjectService {
    enum Behavior: Sendable {
        case projects([ResearchProject])
        case failure(ProjectServiceError)
    }

    var behavior: Behavior = .projects(MockProjectService.samples)
    var delay: Duration = .milliseconds(300)

    func recentProjects(ownerId: String, limit: Int) async throws -> [ResearchProject] {
        if delay > .zero { try await Task.sleep(for: delay) }
        switch behavior {
        case .projects(let projects): return Array(projects.prefix(limit))
        case .failure(let error): throw error
        }
    }

    static let samples: [ResearchProject] = [
        ResearchProject(id: "p1", name: "Climate migration essay", updatedAt: .now.addingTimeInterval(-3_600)),
        ResearchProject(id: "p2", name: "Graph neural networks survey", updatedAt: .now.addingTimeInterval(-86_400 * 2)),
        ResearchProject(id: "p3", name: "History 201: Industrial Revolution", updatedAt: .now.addingTimeInterval(-86_400 * 9)),
    ]
}
