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
        let request = try makeRequest(ownerId: ownerId, limit: limit)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProjectServiceError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ProjectServiceError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            if let parseError = try? JSONDecoder().decode(ParseErrorBody.self, from: data), parseError.code == 209 {
                throw ProjectServiceError.sessionExpired
            }
            throw ProjectServiceError.server(statusCode: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(ProjectListResponse.self, from: data).results.map(\.project)
        } catch {
            throw ProjectServiceError.unexpectedResponse
        }
    }

    func makeRequest(ownerId: String, limit: Int) throws -> URLRequest {
        guard let settings else { throw ProjectServiceError.notConfigured }
        guard let token = sessionToken(), !token.isEmpty else { throw ProjectServiceError.notLoggedIn }

        let whereJSON = try JSONSerialization.data(withJSONObject: ["ownerId": ownerId], options: [.sortedKeys])
        var components = URLComponents(url: settings.baseURL.appendingPathComponent("classes/Project"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "where", value: String(decoding: whereJSON, as: UTF8.self)),
            URLQueryItem(name: "order", value: "-updatedAt"),
            URLQueryItem(name: "limit", value: String(limit)),
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
}

// MARK: - Wire format

private struct ProjectListResponse: Decodable {
    let results: [ProjectRecord]
}

private struct ProjectRecord: Decodable {
    let objectId: String
    let name: String?
    let updatedAt: String?

    var project: ResearchProject {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ResearchProject(id: objectId,
                               name: trimmed.isEmpty ? "Untitled project" : trimmed,
                               updatedAt: updatedAt.flatMap(Self.parseDate))
    }

    /// Parse returns ISO 8601 with milliseconds, e.g. "2026-11-20T18:24:31.123Z".
    static func parseDate(_ string: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string))
            ?? (try? Date.ISO8601FormatStyle().parse(string))
    }
}

private struct ParseErrorBody: Decodable {
    let code: Int
}
