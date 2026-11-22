//
//  PaperChatViewModelTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

@MainActor
final class PaperChatViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PaperChatViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeViewModel(_ service: any ChatService, limit: Int = 20) -> PaperChatViewModel {
        PaperChatViewModel(paper: MockPaperSearchService.sample, service: service,
                           limiter: DailyQuestionLimiter(defaults: defaults, limit: limit))
    }

    func testSendAppendsQuestionAndAnswerAndCountsIt() async {
        let viewModel = makeViewModel(MockChatService(behavior: .answer("It is about OA [1]."), delay: .zero))
        viewModel.draft = "  What is it about?  "

        await viewModel.send()

        XCTAssertEqual(viewModel.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(viewModel.messages.map(\.text), ["What is it about?", "It is about OA [1]."])
        XCTAssertEqual(viewModel.draft, "")
        XCTAssertFalse(viewModel.isSending)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.remainingToday, 19)
    }

    func testEarlierTurnsAreSentAsHistory() async {
        let service = RecordingChatService()
        let viewModel = makeViewModel(service)
        viewModel.draft = "First?"
        await viewModel.send()
        viewModel.draft = "Second?"
        await viewModel.send()

        let histories = await service.histories
        XCTAssertEqual(histories.count, 2)
        XCTAssertEqual(histories[0], [])
        XCTAssertEqual(histories[1].map(\.text), ["First?", "Answer 1"])
    }

    func testEmptyQuestionDoesNothing() async {
        let service = RecordingChatService()
        let viewModel = makeViewModel(service)
        viewModel.draft = "   "
        XCTAssertFalse(viewModel.canSend)
        await viewModel.send()
        XCTAssertTrue(viewModel.messages.isEmpty)
        let calls = await service.histories.count
        XCTAssertEqual(calls, 0)
    }

    func testQuestionOverLimitIsRejected() async {
        let service = RecordingChatService()
        let viewModel = makeViewModel(service)
        viewModel.draft = String(repeating: "a", count: PaperChatViewModel.maxQuestionLength + 1)
        XCTAssertTrue(viewModel.isDraftTooLong)
        XCTAssertFalse(viewModel.canSend)

        await viewModel.send()
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        let calls = await service.histories.count
        XCTAssertEqual(calls, 0)
    }

    func testQuestionAtLimitIsAllowed() {
        let viewModel = makeViewModel(MockChatService(delay: .zero))
        viewModel.draft = String(repeating: "a", count: PaperChatViewModel.maxQuestionLength)
        XCTAssertTrue(viewModel.canSend)
    }

    func testDailyLimitBlocksFurtherQuestions() async {
        let viewModel = makeViewModel(MockChatService(delay: .zero), limit: 1)
        viewModel.draft = "One"
        await viewModel.send()
        XCTAssertTrue(viewModel.hasReachedDailyLimit)

        viewModel.draft = "Two"
        XCTAssertFalse(viewModel.canSend)
        await viewModel.send()
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertTrue(viewModel.errorMessage?.contains("limit") == true)
    }

    func testFailureRestoresDraftShowsMessageAndDoesNotCount() async {
        let viewModel = makeViewModel(MockChatService(behavior: .failure(.quotaExceeded), delay: .zero))
        viewModel.draft = "Will this fail?"

        await viewModel.send()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(viewModel.draft, "Will this fail?")
        XCTAssertEqual(viewModel.errorMessage, ChatError.quotaExceeded.message)
        XCTAssertEqual(viewModel.remainingToday, 20)
    }

    func testOfflineErrorIsMapped() async {
        let viewModel = makeViewModel(MockChatService(behavior: .failure(.offline), delay: .zero))
        viewModel.draft = "Q"
        await viewModel.send()
        XCTAssertEqual(viewModel.errorMessage, ChatError.offline.message)
    }

    func testMissingKeyShowsSetupMessageUpFrontAndCannotSend() async {
        let viewModel = makeViewModel(MockChatService(isConfigured: false, delay: .zero))
        XCTAssertFalse(viewModel.isConfigured)
        XCTAssertEqual(viewModel.errorMessage, ChatError.missingAPIKey.message)
        viewModel.draft = "Q"
        XCTAssertFalse(viewModel.canSend)
        await viewModel.send()
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testTruncatedReplyGetsNote() async {
        let viewModel = makeViewModel(TruncatingChatService())
        viewModel.draft = "Q"
        await viewModel.send()
        XCTAssertTrue(viewModel.messages.last?.text.hasSuffix(PaperChatViewModel.truncationNote) == true)
    }

    func testSourceLabel() {
        let viewModel = makeViewModel(MockChatService(delay: .zero))
        let paper = MockPaperSearchService.sample
        XCTAssertEqual(viewModel.sourceLabel, "[1] \(paper.title) (\(paper.displayYear!))")
    }
}

/// Records the history passed with each question.
private actor RecordingChatService: ChatService {
    private(set) var histories: [[ChatMessage]] = []

    nonisolated var isConfigured: Bool { true }

    func answer(question: String, about paper: Paper, history: [ChatMessage]) async throws -> ChatReply {
        histories.append(history)
        return ChatReply(text: "Answer \(histories.count)", isTruncated: false)
    }
}

private struct TruncatingChatService: ChatService {
    var isConfigured: Bool { true }

    func answer(question: String, about paper: Paper, history: [ChatMessage]) async throws -> ChatReply {
        ChatReply(text: "Partial", isTruncated: true)
    }
}
