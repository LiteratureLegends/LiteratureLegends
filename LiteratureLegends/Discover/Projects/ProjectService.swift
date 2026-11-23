//
//  ProjectService.swift
//  LiteratureLegends · Discover
//
//  "Continue Researching" reads the signed-in user's Projects (readme.md › Schema › Project).
//  Views and view models only see this protocol, so the backend can change without UI changes.
//

import Foundation

/// A row of the Back4App `Project` class.
struct ResearchProject: Identifiable, Equatable, Sendable {
    /// Parse `objectId`.
    let id: String
    let name: String
    let updatedAt: Date?
    let ownerId: String

    init(id: String, name: String, updatedAt: Date?, ownerId: String = "") {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.ownerId = ownerId
    }
}

protocol ProjectService: Sendable {
    /// The user's projects, most recently updated first.
    func recentProjects(ownerId: String, limit: Int) async throws -> [ResearchProject]
    func createProject(name: String, ownerId: String, paper: Paper) async throws -> ResearchProject
    func add(paper: Paper, to project: ResearchProject, ownerId: String) async throws
}

enum ProjectServiceError: Error, Equatable, Sendable {
    /// Back4App keys are missing from Config/Secrets.xcconfig.
    case notConfigured
    /// No session token in the Keychain.
    case notLoggedIn
    /// Parse error 209: the session token is invalid or expired.
    case sessionExpired
    /// No internet connection (only `.notConnectedToInternet` / `.networkConnectionLost`).
    case offline
    case timedOut
    /// Any other URLError (DNS, TLS, cannot connect, ...), with its code for debugging.
    case network(code: Int)
    case server(statusCode: Int)
    case backend(code: Int, message: String)
    case unexpectedResponse

    init(_ error: Error) {
        if let error = error as? ProjectServiceError {
            self = error
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost: self = .offline
            case .timedOut: self = .timedOut
            default: self = .network(code: urlError.code.rawValue)
            }
        } else {
            self = .unexpectedResponse
        }
    }

    var title: String {
        switch self {
        case .notConfigured: "Back4App not set up"
        case .notLoggedIn, .sessionExpired: "Please log in again"
        case .offline: "You're offline"
        case .timedOut, .network, .server, .backend, .unexpectedResponse: "Couldn't load projects"
        }
    }

    var message: String {
        switch self {
        case .notConfigured:
            "Add PARSE_APPLICATION_ID and PARSE_REST_API_KEY to Config/Secrets.xcconfig, then rebuild."
        case .notLoggedIn, .sessionExpired:
            "Your session has expired. Log out and log back in to see your projects."
        case .offline:
            "Check your internet connection and try again."
        case .timedOut:
            "The server took too long to respond. Please try again."
        case .network(let code):
            debugSuffixed("Couldn't reach the server. Please try again.", "URLError \(code)")
        case .server(let statusCode):
            "The server had a problem (HTTP \(statusCode)). Please try again."
        case .backend(_, let message):
            message
        case .unexpectedResponse:
            "Something went wrong. Please try again."
        }
    }

    /// Adds the error code in DEBUG builds only.
    private func debugSuffixed(_ message: String, _ code: String) -> String {
        #if DEBUG
        return "\(message) [\(code)]"
        #else
        return message
        #endif
    }

    /// Retrying can't fix missing configuration.
    var isRetryable: Bool {
        switch self {
        case .notConfigured, .backend: false
        default: true
        }
    }
}
