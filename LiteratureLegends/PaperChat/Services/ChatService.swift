//
//  ChatService.swift
//  LiteratureLegends · PaperChat
//
//  "Ask about this paper". Views and view models only see this protocol, so the Gemini call
//  can later move behind a Parse Cloud Function (e.g. `askDocument` in readme.md) without
//  changing the UI.
//

import Foundation

struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

struct ChatReply: Equatable, Sendable {
    let text: String
    /// The model hit the output-token cap, so the answer may be cut off.
    let isTruncated: Bool
}

protocol ChatService: Sendable {
    /// False when no API key is configured; the UI shows setup steps instead of sending.
    var isConfigured: Bool { get }

    /// Answers `question` using only `paper`'s information, with earlier turns as context.
    func answer(question: String, about paper: Paper, history: [ChatMessage]) async throws -> ChatReply
}

enum ChatError: Error, Equatable, Sendable {
    case missingAPIKey
    /// The key was rejected (invalid, restricted, or reported as leaked).
    case invalidAPIKey
    /// 429: rate limit or free-tier quota reached.
    case quotaExceeded
    case offline
    /// The model declined to answer (safety or policy block).
    case blocked
    /// The response had no text.
    case emptyAnswer
    case server(statusCode: Int)
    case unexpectedResponse

    init(_ error: Error) {
        if let error = error as? ChatError {
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

    var message: String {
        switch self {
        case .missingAPIKey:
            "AI answers need a Gemini API key. Add GEMINI_API_KEY to Config/Secrets.xcconfig, then clean and rebuild."
        case .invalidAPIKey:
            "The Gemini API key was rejected. Check GEMINI_API_KEY in Config/Secrets.xcconfig."
        case .quotaExceeded:
            "The AI is getting too many questions right now (free-tier limit). Please wait a minute and try again."
        case .offline:
            "You're offline. Check your internet connection and try again."
        case .blocked:
            "The AI couldn't answer that question. Try rephrasing it."
        case .emptyAnswer:
            "The AI didn't return an answer. Please try again."
        case .server(let statusCode):
            "The AI service had a problem (HTTP \(statusCode)). Please try again in a moment."
        case .unexpectedResponse:
            "Something went wrong. Please try again."
        }
    }
}
