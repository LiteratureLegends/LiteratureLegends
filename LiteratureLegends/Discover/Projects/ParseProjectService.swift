//
//  ParseProjectService.swift
//  LiteratureLegends · Discover
//
//  Reads Projects from Back4App through the Parse REST API:
//  GET /classes/Project?where={"ownerId":"<user objectId>"}&order=-updatedAt&limit=5
//  Headers: X-Parse-Application-Id, X-Parse-REST-API-Key, X-Parse-Session-Token.
//  Never uses a master key. The session token is read (never written) from Christian's
//  KeychainSessionStore. Never log tokens or keys.
//

import Foundation

/// The public Parse client settings needed for a REST call.
struct ParseRESTSettings: Sendable {
    let baseURL: URL
    let applicationID: String
    let restAPIKey: String

    /// From `ParseConfiguration` (Info.plist / xcconfig), or nil when it isn't configured.
    static func fromParseConfiguration() -> ParseRESTSettings? {
        guard let baseURL = ParseConfiguration.baseURL,
              let restAPIKey = ParseConfiguration.restAPIKey else { return nil }
        return ParseRESTSettings(baseURL: baseURL,
                                 applicationID: ParseConfiguration.applicationID,
                                 restAPIKey: restAPIKey)
    }
}

final class ParseProjectService: ProjectService {
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

    func recentProjects(ownerId: String, limit: Int = 5) async throws -> [ResearchProject] {
        guard limit > 0 else { return [] }
        let pageSize = 100
        var projects: [ResearchProject] = []

        while projects.count < limit {
            let requestedCount = min(pageSize, limit - projects.count)
            let request = try makeRequest(ownerId: ownerId, limit: requestedCount, skip: projects.count)
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                Self.logTransportFailure(operation: "list projects", error: error)
                throw ProjectServiceError(error)
            }
            guard let http = response as? HTTPURLResponse else { throw ProjectServiceError.unexpectedResponse }
            guard (200...299).contains(http.statusCode) else {
                Self.logBackendFailure(operation: "list projects", statusCode: http.statusCode, data: data)
                if let parseError = try? JSONDecoder().decode(ParseErrorBody.self, from: data) {
                    if parseError.code == 209 {
                        throw ProjectServiceError.sessionExpired
                    }
                    throw ProjectServiceError.backend(code: parseError.code, message: parseError.error)
                }
                throw ProjectServiceError.server(statusCode: http.statusCode)
            }

            let page: [ResearchProject]
            do {
                page = try JSONDecoder().decode(ProjectListResponse.self, from: data).results.map(\.project)
            } catch {
                throw ProjectServiceError.unexpectedResponse
            }
            projects.append(contentsOf: page)
            if page.count < requestedCount { break }
        }

        return projects
    }

    func createProject(name: String, ownerId: String, paper: Paper) async throws -> ResearchProject {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProjectServiceError.unexpectedResponse }
        let request = try makeCreateRequest(name: trimmedName, ownerId: ownerId)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logTransportFailure(operation: "create project", error: error)
            throw ProjectServiceError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ProjectServiceError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            Self.logBackendFailure(operation: "create project", statusCode: http.statusCode, data: data)
            if let parseError = try? JSONDecoder().decode(ParseErrorBody.self, from: data) {
                if parseError.code == 209 {
                    throw ProjectServiceError.sessionExpired
                }
                throw ProjectServiceError.backend(code: parseError.code, message: parseError.error)
            }
            throw ProjectServiceError.server(statusCode: http.statusCode)
        }
        guard let created = try? JSONDecoder().decode(ProjectCreateResponse.self, from: data) else {
            Self.logUnexpectedResponse(operation: "create project", data: data)
            throw ProjectServiceError.unexpectedResponse
        }
        try await add(paper: paper, toProjectId: created.objectId, ownerId: ownerId)
        return ResearchProject(id: created.objectId,
                               name: trimmedName,
                               updatedAt: ProjectRecord.parseDate(created.createdAt),
                               ownerId: ownerId)
    }

    func add(paper: Paper, to project: ResearchProject, ownerId: String) async throws {
        try await add(paper: paper, toProjectId: project.id, ownerId: ownerId)
    }

    private func add(paper: Paper, toProjectId projectId: String, ownerId: String) async throws {
        let paperBody: [String: Any] = [
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
            "ACL": [ownerId: ["read": true, "write": true]],
        ]

        let paperId = try await createObject(className: "Paper", body: paperBody)
        _ = try await createObject(className: "ProjectItem", body: [
            "projectId": projectId,
            "paperId": paperId,
            "addedAt": Self.parseDateValue(.now),
            "ACL": [ownerId: ["read": true, "write": true]],
        ])
    }

    private func createObject(className: String, body: [String: Any]) async throws -> String {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }
        var request = URLRequest(url: settings.baseURL.appendingPathComponent("classes/\(className)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue(settings.restAPIKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.setValue(token, forHTTPHeaderField: "X-Parse-Session-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProjectServiceError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            Self.logBackendFailure(operation: "create \(className)", statusCode: http.statusCode, data: data)
            if let parseError = try? JSONDecoder().decode(ParseErrorBody.self, from: data) {
                throw ProjectServiceError.backend(code: parseError.code, message: parseError.error)
            }
            throw ProjectServiceError.server(statusCode: http.statusCode)
        }
        guard let created = try? JSONDecoder().decode(ProjectCreateResponse.self, from: data) else {
            throw ProjectServiceError.unexpectedResponse
        }
        return created.objectId
    }

    private static func parseDateValue(_ date: Date) -> [String: String] {
        ["__type": "Date", "iso": date.ISO8601Format(.iso8601(timeZone: .gmt))]
    }

    func makeRequest(ownerId: String, limit: Int, skip: Int = 0) throws -> URLRequest {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }

        let whereJSON = try JSONSerialization.data(
            withJSONObject: ["ownerId": ownerId],
            options: [.sortedKeys]
        )
        var components = URLComponents(url: settings.baseURL.appendingPathComponent("classes/Project"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "where", value: String(decoding: whereJSON, as: UTF8.self)),
            URLQueryItem(name: "order", value: "-updatedAt"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "skip", value: String(skip)),
            URLQueryItem(name: "keys", value: "name,ownerId,updatedAt"),
        ]
        guard let url = components?.url else { throw ProjectServiceError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(settings.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue(settings.restAPIKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.setValue(token, forHTTPHeaderField: "X-Parse-Session-Token")
        return request
    }

    func makeCreateRequest(name: String, ownerId: String) throws -> URLRequest {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }

        var request = URLRequest(url: settings.baseURL.appendingPathComponent("classes/Project"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue(settings.restAPIKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        request.setValue(token, forHTTPHeaderField: "X-Parse-Session-Token")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": name,
            "ownerId": ownerId,
            "ACL": [ownerId: ["read": true, "write": true]],
        ], options: [.sortedKeys])
        return request
    }

    private static func logBackendFailure(operation: String, statusCode: Int, data: Data) {
        #if DEBUG
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF-8 response body>"
        print("""
        [ParseProjectService] Back4App request failed
          operation: \(operation)
          HTTP status: \(statusCode)
          response: \(body)
        """)
        #endif
    }

    private static func logTransportFailure(operation: String, error: Error) {
        #if DEBUG
        print("""
        [ParseProjectService] Network request failed
          operation: \(operation)
          error: \(error)
        """)
        #endif
    }

    private static func logUnexpectedResponse(operation: String, data: Data) {
        #if DEBUG
        let body = String(data: data, encoding: .utf8) ?? "<non-UTF-8 response body>"
        print("""
        [ParseProjectService] Could not decode Back4App response
          operation: \(operation)
          response: \(body)
        """)
        #endif
    }
}

// MARK: - Wire format

private struct ProjectListResponse: Decodable {
    let results: [ProjectRecord]
}

private struct ProjectCreateResponse: Decodable {
    let objectId: String
    let createdAt: String
}

private struct ProjectRecord: Decodable {
    let objectId: String
    let name: String?
    let updatedAt: String?
    let ownerId: String

    var project: ResearchProject {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ResearchProject(id: objectId,
                               name: trimmed.isEmpty ? "Untitled project" : trimmed,
                               updatedAt: updatedAt.flatMap(Self.parseDate),
                               ownerId: ownerId)
    }

    /// Parse returns ISO 8601 with milliseconds, e.g. "2026-11-20T18:24:31.123Z".
    static func parseDate(_ string: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string))
            ?? (try? Date.ISO8601FormatStyle().parse(string))
    }
}

private struct ParseErrorBody: Decodable {
    let code: Int
    let error: String
}
