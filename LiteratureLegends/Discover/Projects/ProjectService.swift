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
}

protocol ProjectService: Sendable {
    /// The user's projects, most recently updated first.
    func recentProjects(ownerId: String, limit: Int) async throws -> [ResearchProject]
}

enum ProjectServiceError: Error, Equatable, Sendable {
    /// Back4App keys are missing from Config/Secrets.xcconfig.
    case notConfigured
    /// No session token in the Keychain.
    case notLoggedIn
    /// Parse error 209: the session token is invalid or expired.
    case sessionExpired
    case offline
    case server(statusCode: Int)
    case unexpectedResponse

    init(_ error: Error) {
        if let error = error as? ProjectServiceError {
            self = error
        } else if let urlError = error as? URLError, Self.offlineCodes.contains(urlError.code) {
            self = .offline
        } else {
            self = .unexpectedResponse
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed,
    ]

    var title: String {
        switch self {
        case .notConfigured: "Back4App not set up"
        case .notLoggedIn, .sessionExpired: "Please log in again"
        case .offline: "You're offline"
        case .server, .unexpectedResponse: "Couldn't load projects"
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
        case .server(let statusCode):
            "The server had a problem (HTTP \(statusCode)). Please try again."
        case .unexpectedResponse:
            "Something went wrong. Please try again."
        }
    }

    /// Retrying can't fix missing configuration.
    var isRetryable: Bool { self != .notConfigured }
}
