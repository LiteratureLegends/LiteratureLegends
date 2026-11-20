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
    /// No internet connection (only `.notConnectedToInternet` / `.networkConnectionLost`).
    case offline
    /// The request took longer than its timeout; Gemini can stall like this when it is overloaded.
    case timedOut
    /// 503: Gemini is overloaded ("model is currently experiencing high demand").
    case serviceBusy
    /// Any other URLError (DNS, TLS, cannot connect, ...), with its code for debugging.
    case network(code: Int)
    /// The model declined to answer (safety or policy block).
    case blocked
    /// The response had no text.
    case emptyAnswer
    case server(statusCode: Int)
    case unexpectedResponse

    init(_ error: Error) {
        if let error = error as? ChatError {
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

    var message: String {
        #if DEBUG
        if let debugCode { return "\(userMessage) [\(debugCode)]" }
        #endif
        return userMessage
    }

    private var userMessage: String {
        switch self {
        case .missingAPIKey:
            "AI answers need a Gemini API key. Add GEMINI_API_KEY to Config/Secrets.xcconfig, then clean and rebuild."
        case .invalidAPIKey:
            "The Gemini API key was rejected. Check GEMINI_API_KEY in Config/Secrets.xcconfig."
        case .quotaExceeded:
            "The AI is getting too many questions right now (free-tier limit). Please wait a minute and try again."
        case .offline:
            "You're offline. Check your internet connection and try again."
        case .timedOut:
            "The AI took too long to answer. It may be busy right now; please try again."
        case .serviceBusy:
            "The AI is overloaded right now. Please try again in a minute."
        case .network:
            "Couldn't reach the AI service. Please try again."
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

    /// Shown after the message in DEBUG builds only. Never contains the API key.
    private var debugCode: String? {
        switch self {
        case .timedOut: "URLError \(URLError.Code.timedOut.rawValue)"
        case .offline: "offline"
        case .serviceBusy: "HTTP 503"
        case .network(let code): "URLError \(code)"
        case .quotaExceeded: "HTTP 429"
        case .invalidAPIKey: "invalid key"
        case .blocked: "blocked"
        case .emptyAnswer: "empty answer"
        case .unexpectedResponse: "unexpected response"
        case .missingAPIKey, .server: nil
        }
    }
}
