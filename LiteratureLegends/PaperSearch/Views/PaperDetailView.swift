//
//  PaperDetailView.swift
//  LiteratureLegends · PaperSearch
//
//  Drill-down for one search result (#15), with "Ask about this paper" (AI chat).
//  Supports creating a project from a paper or adding it to an existing project.
//

import SwiftUI

struct PaperDetailView: View {
    @State private var viewModel: PaperDetailViewModel
    @State private var isCreatingProject = false
    @State private var isAddingToProject = false
    @State private var createdProjectName: String?
    @State private var addedProjectName: String?
    private let ownerId: String?
    private let projectService: (any ProjectService)?

    init(
        paper: Paper,
        service: any PaperSearchService,
        ownerId: String? = nil,
        projectService: (any ProjectService)? = nil
    ) {
        _viewModel = State(initialValue: PaperDetailViewModel(paper: paper, service: service))
        self.ownerId = ownerId
        self.projectService = projectService
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
                projectSection
                askSection

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
        .sheet(isPresented: $isAddingToProject) {
            if let ownerId, let projectService {
                AddToProjectView(
                    paper: paper,
                    ownerId: ownerId,
                    service: projectService
                ) { project in
                    addedProjectName = project.name
                }
            }
        }
        .sheet(isPresented: $isCreatingProject) {
            if let ownerId, let projectService {
                CreateProjectView(
                    suggestedName: paper.title,
                    paper: paper,
                    ownerId: ownerId,
                    service: projectService
                ) { project in
                    createdProjectName = project.name
                }
            }
        }
        .alert("Added to project", isPresented: Binding(
            get: { addedProjectName != nil },
            set: { if !$0 { addedProjectName = nil } }
        )) {
            Button("OK", role: .cancel) { addedProjectName = nil }
        } message: {
            Text("This paper was added to “\(addedProjectName ?? "")”.")
        }
        .alert("Project created", isPresented: Binding(
            get: { createdProjectName != nil },
            set: { if !$0 { createdProjectName = nil } }
        )) {
            Button("OK", role: .cancel) { createdProjectName = nil }
        } message: {
            Text("“\(createdProjectName ?? "")” was saved to your projects.")
        }
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

    /// The AI answers only from the paper's information, so it needs at least an abstract.
    private var askSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink {
                if let ownerId {
                    PaperChatView(
                        paper: paper,
                        persistence: ParseChatPersistenceService(paper: paper, ownerId: ownerId)
                    )
                } else {
                    PaperChatView(paper: paper)
                }
            } label: {
                Label("Ask about this paper", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(paper.abstract == nil)

            if paper.abstract == nil {
                Text(viewModel.isLoadingDetails
                     ? "Loading the abstract…"
                     : "Not available: this paper has no abstract for the AI to read.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        if ownerId != nil, projectService != nil {
            VStack(spacing: 12) {
                Button {
                    isAddingToProject = true
                } label: {
                    Label("Add to existing project", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    isCreatingProject = true
                } label: {
                    Label("Create project from paper", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }
}

private struct AddToProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [ResearchProject] = []
    @State private var isLoading = true
    @State private var selectedProjectId: String?
    @State private var error: ProjectServiceError?

    let paper: Paper
    let ownerId: String
    let service: any ProjectService
    let onAdded: (ResearchProject) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading projects…")
                } else if projects.isEmpty, error == nil {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "folder",
                        description: Text("Create a project first, then add this paper to it.")
                    )
                } else {
                    List(projects) { project in
                        Button {
                            Task { await add(to: project) }
                        } label: {
                            HStack {
                                Label(project.name, systemImage: "folder")
                                Spacer()
                                if selectedProjectId == project.id {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(selectedProjectId != nil)
                    }
                }
            }
            .navigationTitle("Add to project")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(selectedProjectId != nil)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(selectedProjectId != nil)
                }
            }
            .task { await loadProjects() }
            .alert("Couldn’t add paper", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK", role: .cancel) { error = nil }
            } message: {
                Text(error?.message ?? "Please try again.")
            }
        }
    }

    @MainActor
    private func loadProjects() async {
        guard isLoading else { return }
        do {
            projects = try await service.recentProjects(ownerId: ownerId, limit: 100)
        } catch {
            self.error = ProjectServiceError(error)
        }
        isLoading = false
    }

    @MainActor
    private func add(to project: ResearchProject) async {
        guard selectedProjectId == nil else { return }
        selectedProjectId = project.id
        do {
            try await service.add(paper: paper, to: project, ownerId: ownerId)
            onAdded(project)
            dismiss()
        } catch {
            self.error = ProjectServiceError(error)
            selectedProjectId = nil
        }
    }
}

private struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var error: ProjectServiceError?

    let paper: Paper
    let ownerId: String
    let service: any ProjectService
    let onCreated: (ResearchProject) -> Void

    init(
        suggestedName: String,
        paper: Paper,
        ownerId: String,
        service: any ProjectService,
        onCreated: @escaping (ResearchProject) -> Void
    ) {
        _name = State(initialValue: suggestedName)
        self.paper = paper
        self.ownerId = ownerId
        self.service = service
        self.onCreated = onCreated
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project name") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                if let error {
                    Section {
                        Label(error.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(trimmedName.isEmpty || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Creating project…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @MainActor
    private func create() async {
        guard !isSaving, !trimmedName.isEmpty else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let project = try await service.createProject(name: trimmedName, ownerId: ownerId, paper: paper)
            onCreated(project)
            dismiss()
        } catch {
            self.error = ProjectServiceError(error)
        }
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
