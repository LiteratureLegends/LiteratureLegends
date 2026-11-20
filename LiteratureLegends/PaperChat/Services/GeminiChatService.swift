//
//  GeminiChatService.swift
//  LiteratureLegends · PaperChat
//
//  Calls the Gemini API directly from the app with URLSession (no SDK):
//  POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
//  The key goes in the x-goog-api-key header, never in the URL. Never log the key.
//
//  TODO: Move the Gemini key to Back4App Cloud Code (e.g. an `askDocument` Cloud Function)
//  so it no longer ships inside the app; then replace this with a ParseChatService.
//

import Foundation

final class GeminiChatService: ChatService {
    static let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
    /// Caps answer length. On Gemini 3.x this budget is shared with the model's thinking tokens.
    static let maxOutputTokens = 2048
    /// `gemini-3.8-flash` supports LOW/MEDIUM/HIGH (not MINIMAL); LOW keeps answers fast and cheap.
    static let thinkingLevel = "LOW"
    /// Earlier messages sent as context, to bound request size.
    static let maxHistoryMessages = 10
    /// Wait before the single automatic retry after HTTP 503 (overloaded) or a timeout.
    static let defaultRetryDelay: Duration = .seconds(2)

    static let systemInstruction = """
    You are a research assistant for students. Answer only from the provided paper information. \
    If the answer isn't in it, say so plainly instead of guessing. Cite the paper as [1] whenever \
    you use information from it. Keep answers concise and clear.
    """

    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let bundleIdentifier: String?
    private let retryDelay: Duration

    init(
        apiKey: String? = AppConfig.geminiAPIKey,
        model: String = AppConfig.geminiModel,
        session: URLSession = .shared,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        retryDelay: Duration = GeminiChatService.defaultRetryDelay
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.bundleIdentifier = bundleIdentifier
        self.retryDelay = retryDelay
    }

    var isConfigured: Bool { apiKey != nil }

    func answer(question: String, about paper: Paper, history: [ChatMessage]) async throws -> ChatReply {
        let request = try makeRequest(question: question, paper: paper, history: history)
        do {
            return try await send(request)
        } catch let error as ChatError where Self.isRetryable(error) {
            // Gemini returns 503 or stalls when overloaded; one retry after a short wait often succeeds.
            try await Task.sleep(for: retryDelay)
            return try await send(request)
        }
    }

    /// Only transient overload errors are retried, and only once.
    static func isRetryable(_ error: ChatError) -> Bool {
        error == .serviceBusy || error == .timedOut
    }

    private func send(_ request: URLRequest) async throws -> ChatReply {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ChatError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ChatError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            throw Self.error(forStatus: http.statusCode, body: data)
        }
        return try Self.parseReply(data)
    }

    // MARK: Request

    func makeRequest(question: String, paper: Paper, history: [ChatMessage]) throws -> URLRequest {
        guard let apiKey else { throw ChatError.missingAPIKey }

        var request = URLRequest(url: Self.baseURL.appendingPathComponent("\(model):generateContent"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        // Lets the key be restricted to this iOS app in Google Cloud Console.
        if let bundleIdentifier {
            request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        request.httpBody = try JSONEncoder().encode(Self.makeBody(question: question, paper: paper, history: history))
        return request
    }

    static func makeBody(question: String, paper: Paper, history: [ChatMessage]) -> GenerateContentRequest {
        var contents = trimmedHistory(history).map { message in
            GenerateContentRequest.Content(role: message.role == .user ? "user" : "model",
                                           parts: [.init(text: message.text)])
        }
        contents.append(.init(role: "user", parts: [.init(text: question)]))

        return GenerateContentRequest(
            systemInstruction: .init(role: nil, parts: [.init(text: systemInstruction + "\n\n" + paperContext(paper))]),
            contents: contents,
            generationConfig: .init(maxOutputTokens: maxOutputTokens,
                                    thinkingConfig: .init(thinkingLevel: thinkingLevel))
        )
    }

    /// The last `maxHistoryMessages` messages, starting with a user turn as the API expects.
    static func trimmedHistory(_ history: [ChatMessage]) -> [ChatMessage] {
        var recent = Array(history.suffix(maxHistoryMessages))
        while recent.first?.role == .assistant { recent.removeFirst() }
        return recent
    }

    /// The only source the model may use, labeled [1].
    static func paperContext(_ paper: Paper) -> String {
        var lines = ["Paper information [1]:", "Title: \(paper.title)"]
        if !paper.authors.isEmpty {
            let shown = paper.authors.prefix(20).joined(separator: ", ")
            lines.append("Authors: \(paper.authors.count > 20 ? shown + ", et al." : shown)")
        }
        if let year = paper.displayYear { lines.append("Year: \(year)") }
        if let venue = paper.venue { lines.append("Venue: \(venue)") }
        if let doi = paper.doi { lines.append("DOI: \(doi)") }
        if let url = paper.openURL { lines.append("Link: \(url.absoluteString)") }
        lines.append("Abstract: \(paper.abstract ?? "Not available.")")
        return lines.joined(separator: "\n")
    }

    // MARK: Response

    static func parseReply(_ data: Data) throws -> ChatReply {
        let response: GenerateContentResponse
        do {
            response = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        } catch {
            throw ChatError.unexpectedResponse
        }
        if response.promptFeedback?.blockReason != nil { throw ChatError.blocked }
        guard let candidate = response.candidates?.first else { throw ChatError.emptyAnswer }

        let text = (candidate.content?.parts ?? [])
            .filter { $0.thought != true }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            if let reason = candidate.finishReason, blockedFinishReasons.contains(reason) {
                throw ChatError.blocked
            }
            throw ChatError.emptyAnswer
        }
        return ChatReply(text: text, isTruncated: candidate.finishReason == "MAX_TOKENS")
    }

    private static let blockedFinishReasons: Set<String> = [
        "SAFETY", "RECITATION", "BLOCKLIST", "PROHIBITED_CONTENT", "SPII",
    ]

    static func error(forStatus status: Int, body: Data) -> ChatError {
        let apiError = (try? JSONDecoder().decode(GoogleErrorResponse.self, from: body))?.error
        let text = [apiError?.status, apiError?.message].compactMap { $0 }.joined(separator: " ")
        switch status {
        case 429:
            return .quotaExceeded
        case 401, 403:
            return .invalidAPIKey
        case 400 where text.localizedCaseInsensitiveContains("API key") || text.contains("API_KEY_INVALID"):
            return .invalidAPIKey
        case 503:
            return .serviceBusy
        default:
            return .server(statusCode: status)
        }
    }
}

// MARK: - Wire format

struct GenerateContentRequest: Encodable, Equatable {
    struct Part: Encodable, Equatable {
        let text: String
    }

    struct Content: Encodable, Equatable {
        let role: String?
        let parts: [Part]
    }

    struct ThinkingConfig: Encodable, Equatable {
        let thinkingLevel: String
    }

    struct GenerationConfig: Encodable, Equatable {
        let maxOutputTokens: Int
        let thinkingConfig: ThinkingConfig
    }

    let systemInstruction: Content
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
                let thought: Bool?
            }
            let parts: [Part]?
        }
        let content: Content?
        let finishReason: String?
    }

    struct PromptFeedback: Decodable {
        let blockReason: String?
    }

    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback?
}

/// Google's error body: {"error": {"code": 429, "message": "...", "status": "RESOURCE_EXHAUSTED"}}.
private struct GoogleErrorResponse: Decodable {
    struct Body: Decodable {
        let message: String?
        let status: String?
    }
    let error: Body
}
