import Foundation

protocol ChatPersisting: Sendable {
    func prepare(paperTitle: String) async throws
    func saveTurn(userMessage: ChatMessage, assistantMessage: ChatMessage, paperTitle: String) async throws
}

actor ParseChatPersistenceService: ChatPersisting {
    private var projectId: String?
    private var paperId: String?
    private let ownerId: String
    private let paperToCreate: Paper?
    private let settings: ParseRESTSettings?
    private let session: URLSession
    private let sessionToken: @Sendable () -> String?

    private var conversationId: String?
    private var nextSequenceNumber = 0

    init(
        projectId: String,
        paperId: String,
        ownerId: String,
        settings: ParseRESTSettings? = .fromParseConfiguration(),
        session: URLSession = .shared,
        sessionToken: @escaping @Sendable () -> String? = { KeychainSessionStore().read() }
    ) {
        self.projectId = projectId
        self.paperId = paperId
        self.ownerId = ownerId
        self.paperToCreate = nil
        self.settings = settings
        self.session = session
        self.sessionToken = sessionToken
    }

    init(
        paper: Paper,
        ownerId: String,
        settings: ParseRESTSettings? = .fromParseConfiguration(),
        session: URLSession = .shared,
        sessionToken: @escaping @Sendable () -> String? = { KeychainSessionStore().read() }
    ) {
        self.projectId = nil
        self.paperId = nil
        self.ownerId = ownerId
        self.paperToCreate = paper
        self.settings = settings
        self.session = session
        self.sessionToken = sessionToken
    }

    func prepare(paperTitle: String) async throws {
        guard conversationId == nil else { return }
        let resolvedPaperId = try await resolvePaperId()
        let resolvedProjectId = try await resolveProjectId(
            paperId: resolvedPaperId,
            paperTitle: paperTitle
        )
        let body: [String: Any] = [
            "projectId": resolvedProjectId,
            "paperId": resolvedPaperId,
            "title": paperTitle,
            "ACL": ownerACL,
        ]
        conversationId = try await create(className: "Conversation", body: body)
    }

    func saveTurn(userMessage: ChatMessage, assistantMessage: ChatMessage, paperTitle: String) async throws {
        try await prepare(paperTitle: paperTitle)
        guard let conversationId else { throw ProjectServiceError.unexpectedResponse }

        try await saveMessage(userMessage, conversationId: conversationId)
        try await saveMessage(assistantMessage, conversationId: conversationId)
        try await touchConversation(conversationId, title: paperTitle)
    }

    private func resolvePaperId() async throws -> String {
        if let paperId { return paperId }
        guard let paper = paperToCreate else { throw ProjectServiceError.unexpectedResponse }
        let body: [String: Any] = [
            "externalApiId": paper.externalApiId,
            "externalApiSource": paper.externalApiSource,
            "title": paper.title,
            "authors": paper.authors,
            "doi": paper.doi as Any? ?? NSNull(),
            "publicationDate": paper.publicationDate.map(Self.parseDateValue) as Any? ?? NSNull(),
            "publicationYear": paper.publicationYear as Any? ?? NSNull(),
            "venue": paper.venue as Any? ?? NSNull(),
            "abstract": paper.abstract as Any? ?? NSNull(),
            "citationCount": paper.citationCount as Any? ?? NSNull(),
            "sourceUrl": paper.sourceUrl,
            "retrievedAt": Self.parseDateValue(paper.retrievedAt),
            "ACL": ownerACL,
        ]
        let createdPaperId = try await create(className: "Paper", body: body)
        paperId = createdPaperId
        return createdPaperId
    }

    private func resolveProjectId(paperId: String, paperTitle: String) async throws -> String {
        if let projectId { return projectId }

        let createdProjectId = try await create(
            className: "Project",
            body: [
                "name": paperTitle,
                "ownerId": ownerId,
                "ACL": ownerACL,
            ]
        )
        _ = try await create(
            className: "ProjectItem",
            body: [
                "projectId": createdProjectId,
                "paperId": paperId,
                "addedAt": Self.parseDateValue(.now),
                "ACL": ownerACL,
            ]
        )
        projectId = createdProjectId
        return createdProjectId
    }

    private static func parseDateValue(_ date: Date) -> [String: String] {
        ["__type": "Date", "iso": date.ISO8601Format(.iso8601(timeZone: .gmt))]
    }

    private var ownerACL: [String: [String: Bool]] {
        [ownerId: ["read": true, "write": true]]
    }

    private func saveMessage(_ message: ChatMessage, conversationId: String) async throws {
        _ = try await create(
            className: "Message",
            body: [
                "conversationId": conversationId,
                "role": message.role.rawValue,
                "content": message.text,
                "sequenceNumber": nextSequenceNumber,
                "ACL": ownerACL,
            ]
        )
        nextSequenceNumber += 1
    }

    private func create(className: String, body: [String: Any]) async throws -> String {
        let request = try makeRequest(
            className: className,
            method: "POST",
            objectId: nil,
            body: body
        )
        let data = try await perform(request, operation: "create \(className)")
        guard let response = try? JSONDecoder().decode(ChatCreateResponse.self, from: data) else {
            logDecodeFailure(className: className, data: data)
            throw ProjectServiceError.unexpectedResponse
        }
        return response.objectId
    }

    private func touchConversation(_ objectId: String, title: String) async throws {
        let request = try makeRequest(
            className: "Conversation",
            method: "PUT",
            objectId: objectId,
            body: ["title": title]
        )
        _ = try await perform(request, operation: "update Conversation")
    }

    private func makeRequest(
        className: String,
        method: String,
        objectId: String?,
        body: [String: Any]
    ) throws -> URLRequest {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }
        var url = settings.baseURL.appendingPathComponent("classes/\(className)")
        if let objectId {
            url.appendPathComponent(objectId)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue(settings.restAPIKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.setValue(token, forHTTPHeaderField: "X-Parse-Session-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        #if DEBUG
        if let httpBody = request.httpBody {
            print("[ParseChatPersistenceService] \(method) \(url.absoluteString) request body:\n\(String(decoding: httpBody, as: UTF8.self))")
        }
        #endif
        return request
    }

    private func perform(_ request: URLRequest, operation: String) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[ParseChatPersistenceService] \(operation) network error: \(error)")
            #endif
            throw ProjectServiceError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ProjectServiceError.unexpectedResponse
        }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[ParseChatPersistenceService] \(operation) HTTP \(http.statusCode): \(String(decoding: data, as: UTF8.self))")
            #endif
            if let parseError = try? JSONDecoder().decode(ChatParseError.self, from: data) {
                if parseError.code == 209 {
                    throw ProjectServiceError.sessionExpired
                }
                throw ProjectServiceError.backend(code: parseError.code, message: parseError.error)
            }
            throw ProjectServiceError.server(statusCode: http.statusCode)
        }
        return data
    }

    private func logDecodeFailure(className: String, data: Data) {
        #if DEBUG
        print("[ParseChatPersistenceService] Could not decode \(className): \(String(decoding: data, as: UTF8.self))")
        #endif
    }
}

private struct ChatCreateResponse: Decodable {
    let objectId: String
}

private struct ChatParseError: Decodable {
    let code: Int
    let error: String
}
