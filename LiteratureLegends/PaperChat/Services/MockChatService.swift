//
//  MockChatService.swift
//  LiteratureLegends · PaperChat
//
//  In-memory ChatService for SwiftUI previews. No networking.
//

import Foundation

struct MockChatService: ChatService {
    enum Behavior: Sendable {
        case answer(String)
        case failure(ChatError)
    }

    var behavior: Behavior = .answer("The paper reports that about 28% of the scholarly literature is open access [1].")
    var isConfigured = true
    var delay: Duration = .milliseconds(800)

    func answer(question: String, about paper: Paper, history: [ChatMessage]) async throws -> ChatReply {
        if delay > .zero { try await Task.sleep(for: delay) }
        switch behavior {
        case .answer(let text): return ChatReply(text: text, isTruncated: false)
        case .failure(let error): throw error
        }
    }
}
