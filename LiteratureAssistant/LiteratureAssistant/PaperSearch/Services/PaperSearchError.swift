//
//  PaperSearchError.swift
//  LiteratureAssistant · PaperSearch
//

import Foundation

nonisolated enum PaperSearchError: Error, Equatable, Sendable {
    case missingAPIKey
    case invalidAPIKey
    case keyNotActivated
    case offline
    case timedOut
    /// HTTP 429: per-second limit or daily budget exceeded.
    case rateLimited(retryAfterSeconds: Int?)
    case invalidQuery(String)
    case notFound
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case decoding
    case network

    /// Maps any thrown error (URLError, decoding, ...) to a PaperSearchError.
    init(_ error: Error) {
        switch error {
        case let error as PaperSearchError:
            self = error
        case let error as URLError:
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .cannotFindHost, .dnsLookupFailed:
                self = .offline
            case .timedOut:
                self = .timedOut
            default:
                self = .network
            }
        case is DecodingError:
            self = .decoding
        default:
            self = .network
        }
    }

    var title: String {
        switch self {
        case .missingAPIKey, .invalidAPIKey, .keyNotActivated: "API key problem"
        case .offline: "You're offline"
        case .timedOut: "Request timed out"
        case .rateLimited: "Too many searches"
        case .invalidQuery: "Check your search"
        case .notFound: "Paper not found"
        case .clientError: "Search couldn't be completed"
        case .serverError: "OpenAlex is having trouble"
        case .decoding: "Unexpected response"
        case .network: "Connection problem"
        }
    }

    var message: String {
        switch self {
        case .missingAPIKey:
            "No OpenAlex API key is configured. Add one to Config/Secrets.xcconfig and rebuild."
        case .invalidAPIKey:
            "OpenAlex rejected the API key. Check the key in Config/Secrets.xcconfig."
        case .keyNotActivated:
            "Your OpenAlex API key isn't active yet. Click the activation link OpenAlex emailed you, then try again."
        case .offline:
            "Check your internet connection and try again."
        case .timedOut:
            "OpenAlex took too long to respond. Try again in a moment."
        case .rateLimited(let seconds):
            if let seconds, seconds > 0 {
                "You've hit OpenAlex's rate limit. Try again in \(seconds) second\(seconds == 1 ? "" : "s")."
            } else {
                "You've hit OpenAlex's rate limit. Wait a moment and try again."
            }
        case .invalidQuery(let reason):
            reason
        case .notFound:
            "OpenAlex has no record for this paper."
        case .clientError(let code):
            "OpenAlex couldn't process this search (error \(code)). Try different wording."
        case .serverError(let code):
            "OpenAlex is busy or unavailable right now (error \(code)). Try again in a minute."
        case .decoding:
            "OpenAlex sent data the app couldn't read. Try again later."
        case .network:
            "Something went wrong while contacting OpenAlex. Try again."
        }
    }

    /// Whether a Retry button makes sense (it doesn't for configuration problems).
    var isRetryable: Bool {
        switch self {
        case .missingAPIKey, .invalidAPIKey, .invalidQuery: false
        default: true
        }
    }
}

nonisolated extension PaperSearchError: LocalizedError {
    var errorDescription: String? { message }
}
