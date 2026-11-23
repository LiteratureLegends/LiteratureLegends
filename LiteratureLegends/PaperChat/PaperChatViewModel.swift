//
//  PaperChatViewModel.swift
//  LiteratureLegends · PaperChat
//
//  Keeps the conversation in memory and sends earlier turns as context.
//  TODO: Save Conversation/Message (readme.md › Schema) to Back4App so chats persist and can be
//  saved to a project.
//

import Foundation
import Observation

@MainActor
@Observable
final class PaperChatViewModel {
    static let maxQuestionLength = 1_000
    static let truncationNote = "\n\n_(Answer shortened to stay within the length limit.)_"

    let paper: Paper
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var isSending = false
    /// The last problem to show above the input field, or nil.
    private(set) var errorMessage: String?
    /// Questions left today; copied from the limiter so the view observes changes.
    private(set) var remainingToday: Int

    private let service: any ChatService
    private let limiter: DailyQuestionLimiter

    /// `limiter` defaults to a UserDefaults-backed limit of 20 questions per day.
    init(paper: Paper, service: any ChatService, limiter: DailyQuestionLimiter? = nil) {
        let limiter = limiter ?? DailyQuestionLimiter()
        self.paper = paper
        self.service = service
        self.limiter = limiter
        self.remainingToday = limiter.remainingToday
        if !service.isConfigured { errorMessage = ChatError.missingAPIKey.message }
    }

    var isConfigured: Bool { service.isConfigured }
    var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isDraftTooLong: Bool { trimmedDraft.count > Self.maxQuestionLength }
    var hasReachedDailyLimit: Bool { remainingToday == 0 }

    var canSend: Bool {
        isConfigured && !isSending && !trimmedDraft.isEmpty && !isDraftTooLong && !hasReachedDailyLimit
    }

    /// "[1] Title (Year)" for the source footer.
    var sourceLabel: String {
        if let year = paper.displayYear { return "[1] \(paper.title) (\(year))" }
        return "[1] \(paper.title)"
    }

    func send() async {
        let question = trimmedDraft
        guard !isSending else { return }
        guard isConfigured else { errorMessage = ChatError.missingAPIKey.message; return }
        guard !question.isEmpty else { return }
        guard question.count <= Self.maxQuestionLength else {
            errorMessage = "Questions can be up to \(Self.maxQuestionLength.formatted()) characters."
            return
        }
        guard limiter.canAsk else {
            errorMessage = "You've reached today's limit of \(limiter.limit) questions. Come back tomorrow!"
            return
        }

        let history = messages
        let userMessage = ChatMessage(role: .user, text: question)
        messages.append(userMessage)
        draft = ""
        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            let reply = try await service.answer(question: question, about: paper, history: history)
            messages.append(ChatMessage(role: .assistant,
                                        text: reply.text + (reply.isTruncated ? Self.truncationNote : "")))
            limiter.recordQuestion()
            remainingToday = limiter.remainingToday
        } catch {
            // Drop the unanswered question so history stays in user/model pairs; restore it for a retry.
            messages.removeAll { $0.id == userMessage.id }
            if draft.isEmpty { draft = question }
            errorMessage = error is CancellationError ? nil : ChatError(error).message
        }
    }
}
