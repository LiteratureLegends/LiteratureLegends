//
//  ContinueResearchingView.swift
//  LiteratureLegends · Discover
//
//  The signed-in user's most recently updated Projects (Back4App), per images/Wireframe2.jpeg.
//

import SwiftUI

struct ContinueResearchingView: View {
    let viewModel: ContinueResearchingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Projects")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            switch viewModel.state {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading your projects…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            case .empty:
                messageCard(title: "No projects yet",
                            message: "Projects you create will show up here.",
                            systemImage: "folder")
            case .loaded(let projects):
                VStack(spacing: 10) {
                    ForEach(projects) { project in
                        // TODO: Open the project once a Project detail screen exists (Library/Profile).
                        ProjectRowView(project: project)
                    }
                }
            case .error(let error):
                messageCard(title: error.title, message: error.message,
                            systemImage: error == .offline ? "wifi.slash" : "exclamationmark.triangle",
                            retry: error.isRetryable ? { Task { await viewModel.retry() } } : nil)
            }
        }
    }

    private func messageCard(title: String, message: String, systemImage: String,
                             retry: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let retry {
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ProjectRowView: View {
    let project: ResearchProject

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                    .lineLimit(2)
                if let updatedAt = project.updatedAt {
                    Text("Updated \(updatedAt, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private func previewSection(_ behavior: MockProjectService.Behavior) -> some View {
    let viewModel = ContinueResearchingViewModel(ownerId: "preview",
                                                 service: MockProjectService(behavior: behavior))
    return ScrollView {
        ContinueResearchingView(viewModel: viewModel).padding()
    }
    .task { await viewModel.loadIfNeeded() }
}

#Preview("Projects") { previewSection(.projects(MockProjectService.samples)) }
#Preview("Empty") { previewSection(.projects([])) }
#Preview("Error") { previewSection(.failure(.offline)) }
#Preview("Not configured") { previewSection(.failure(.notConfigured)) }
