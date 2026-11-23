import Foundation
import Observation
import SwiftUI

struct StoredConversation: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let updatedAt: Date?
}

struct StoredPaper: Identifiable, Equatable, Sendable {
    let id: String
    let paper: Paper
}

struct ProjectWorkspace: Equatable, Sendable {
    let papers: [StoredPaper]
    let conversations: [StoredConversation]
}

protocol ProjectWorkspaceServicing: Sendable {
    func workspace(projectId: String) async throws -> ProjectWorkspace
    func messages(conversationId: String) async throws -> [ChatMessage]
}

final class ParseProjectWorkspaceService: ProjectWorkspaceServicing {
    private let settings: ParseRESTSettings?
    private let session: URLSession
    private let sessionToken: @Sendable () -> String?

    init(
        settings: ParseRESTSettings? = .fromParseConfiguration(),
        session: URLSession = .shared,
        sessionToken: @escaping @Sendable () -> String? = { KeychainSessionStore().read() }
    ) {
        self.settings = settings
        self.session = session
        self.sessionToken = sessionToken
    }

    func workspace(projectId: String) async throws -> ProjectWorkspace {
        async let conversations = fetchConversations(projectId: projectId)
        async let papers = fetchPapers(projectId: projectId)
        return try await ProjectWorkspace(papers: papers, conversations: conversations)
    }

    func messages(conversationId: String) async throws -> [ChatMessage] {
        let records: [MessageRecord] = try await get(
            className: "Message",
            where: ["conversationId": conversationId],
            order: "sequenceNumber"
        )
        return records.compactMap { record in
            guard let role = ChatMessage.Role(rawValue: record.role) else { return nil }
            return ChatMessage(role: role, text: record.content)
        }
    }

    private func fetchConversations(projectId: String) async throws -> [StoredConversation] {
        let records: [ConversationRecord]
        do {
            records = try await get(
                className: "Conversation",
                where: ["projectId": projectId],
                order: "-updatedAt"
            )
        } catch ProjectServiceError.backend(code: 101, message: _) {
            // Parse reports a missing class until its first object is created.
            return []
        } catch ProjectServiceError.backend(code: 119, message: _) {
            // Conversations are optional on the project page. Some Back4App
            // configurations deny find access until conversation data exists.
            return []
        }
        return records.map {
            StoredConversation(
                id: $0.objectId,
                title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Untitled conversation"
                    : $0.title,
                updatedAt: $0.updatedAt.flatMap(Self.parseDate)
            )
        }
    }

    private func fetchPapers(projectId: String) async throws -> [StoredPaper] {
        let items: [ProjectItemRecord] = try await get(
            className: "ProjectItem",
            where: ["projectId": projectId],
            order: "-addedAt"
        )
        let paperIds = items.compactMap(\.paperId)
        guard !paperIds.isEmpty else { return [] }
        let records: [PaperRecord] = try await get(
            className: "Paper",
            where: ["objectId": ["$in": paperIds]],
            order: nil
        )
        let papersById = Dictionary(
            uniqueKeysWithValues: records.map { ($0.objectId, StoredPaper(id: $0.objectId, paper: $0.paper)) }
        )
        return paperIds.compactMap { papersById[$0] }
    }

    private func get<Record: Decodable>(
        className: String,
        where whereObject: [String: Any],
        order: String?
    ) async throws -> [Record] {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }
        let whereData = try JSONSerialization.data(withJSONObject: whereObject, options: [.sortedKeys])
        var components = URLComponents(
            url: settings.baseURL.appendingPathComponent("classes/\(className)"),
            resolvingAgainstBaseURL: false
        )
        var queryItems = [
            URLQueryItem(name: "where", value: String(decoding: whereData, as: UTF8.self)),
            URLQueryItem(name: "limit", value: "1000"),
        ]
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw ProjectServiceError.notConfigured }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(settings.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue(settings.restAPIKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.setValue(token, forHTTPHeaderField: "X-Parse-Session-Token")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProjectServiceError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[ParseProjectWorkspaceService] \(className) HTTP \(http.statusCode): \(String(decoding: data, as: UTF8.self))")
            #endif
            if let parseError = try? JSONDecoder().decode(WorkspaceParseError.self, from: data) {
                if parseError.code == 209 {
                    throw ProjectServiceError.sessionExpired
                }
                throw ProjectServiceError.backend(code: parseError.code, message: parseError.error)
            }
            throw ProjectServiceError.server(statusCode: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(ParseListResponse<Record>.self, from: data).results
        } catch {
            #if DEBUG
            print("""
            [ParseProjectWorkspaceService] Could not decode \(className)
              error: \(error)
              response: \(String(decoding: data, as: UTF8.self))
            """)
            #endif
            throw ProjectServiceError.unexpectedResponse
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value))
            ?? (try? Date.ISO8601FormatStyle().parse(value))
    }
}

private struct ParseListResponse<Record: Decodable>: Decodable {
    let results: [Record]
}

private struct WorkspaceParseError: Decodable {
    let code: Int
    let error: String
}

private struct ProjectItemRecord: Decodable {
    let paperId: String?
}

private struct ConversationRecord: Decodable {
    let objectId: String
    let title: String
    let updatedAt: String?
}

private struct MessageRecord: Decodable {
    let role: String
    let content: String
}

private struct PaperRecord: Decodable {
    let objectId: String
    let externalApiId: String
    let externalApiSource: String
    let title: String
    let authors: [String]
    let doi: String?
    let publicationDate: ParseDateValue?
    let publicationYear: Int?
    let venue: String?
    let abstract: String?
    let citationCount: Int?
    let sourceUrl: String
    let retrievedAt: ParseDateValue?

    var paper: Paper {
        Paper(
            externalApiId: externalApiId,
            externalApiSource: externalApiSource,
            title: title,
            authors: authors,
            doi: doi,
            publicationDate: publicationDate?.date,
            publicationYear: publicationYear,
            venue: venue,
            abstract: abstract,
            citationCount: citationCount,
            sourceUrl: sourceUrl,
            retrievedAt: retrievedAt?.date ?? .now
        )
    }
}

private struct ParseDateValue: Decodable {
    let iso: String

    var date: Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(iso))
            ?? (try? Date.ISO8601FormatStyle().parse(iso))
    }
}

@MainActor
@Observable
private final class ProjectWorkspaceViewModel {
    enum State {
        case loading
        case loaded(ProjectWorkspace)
        case failed(ProjectServiceError)
    }

    private(set) var state: State = .loading
    private let projectId: String
    private let service: any ProjectWorkspaceServicing

    init(projectId: String, service: any ProjectWorkspaceServicing) {
        self.projectId = projectId
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await service.workspace(projectId: projectId))
        } catch {
            state = .failed(ProjectServiceError(error))
        }
    }
}

struct ProjectWorkspaceView: View {
    let project: ResearchProject
    @State private var viewModel: ProjectWorkspaceViewModel

    init(
        project: ResearchProject,
        service: any ProjectWorkspaceServicing = ParseProjectWorkspaceService()
    ) {
        self.project = project
        _viewModel = State(initialValue: ProjectWorkspaceViewModel(projectId: project.id, service: service))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading project…")
            case .failed(let error):
                ContentUnavailableView {
                    Label(error.title, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.message)
                } actions: {
                    Button("Retry") { Task { await viewModel.load() } }
                }
            case .loaded(let workspace):
                List {
                    Section("Papers") {
                        if workspace.papers.isEmpty {
                            Text("No papers saved to this project.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(workspace.papers) { storedPaper in
                                NavigationLink {
                                    PaperChatView(
                                        paper: storedPaper.paper,
                                        persistence: ParseChatPersistenceService(
                                            projectId: project.id,
                                            paperId: storedPaper.id,
                                            ownerId: project.ownerId
                                        )
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(storedPaper.paper.title)
                                        Text(storedPaper.paper.shortAuthorList)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section("Conversations") {
                        if workspace.conversations.isEmpty {
                            Text("No conversations saved to this project.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(workspace.conversations) { conversation in
                                NavigationLink {
                                    StoredConversationView(conversation: conversation)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conversation.title)
                                        if let updatedAt = conversation.updatedAt {
                                            Text(updatedAt, format: .relative(presentation: .named))
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

private struct StoredConversationView: View {
    let conversation: StoredConversation
    @State private var messages: [ChatMessage]?
    @State private var error: ProjectServiceError?
    private let service: any ProjectWorkspaceServicing = ParseProjectWorkspaceService()

    var body: some View {
        ScrollView {
            if let messages {
                if messages.isEmpty {
                    ContentUnavailableView("No messages", systemImage: "bubble.left.and.bubble.right")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.role == .user { Spacer(minLength: 40) }
                                Text(message.text)
                                    .padding(12)
                                    .background(
                                        message.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(.background.secondary),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .foregroundStyle(message.role == .user ? .white : .primary)
                                if message.role == .assistant { Spacer(minLength: 40) }
                            }
                        }
                    }
                    .padding()
                }
            } else if let error {
                ContentUnavailableView(
                    "Couldn't load conversation",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.message)
                )
            } else {
                ProgressView("Loading conversation…")
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                messages = try await service.messages(conversationId: conversation.id)
            } catch {
                self.error = ProjectServiceError(error)
            }
        }
    }
}
