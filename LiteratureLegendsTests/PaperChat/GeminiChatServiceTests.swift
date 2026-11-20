//
//  GeminiChatServiceTests.swift
//  LiteratureLegendsTests
//
//  All requests go through MockURLProtocol; nothing touches the network.
//

import XCTest
@testable import LiteratureLegends

final class GeminiChatServiceTests: XCTestCase {
    private let apiKey = "TEST_GEMINI_KEY"

    private let paper = Paper(
        externalApiId: "W1",
        title: "The state of OA",
        authors: ["Heather Piwowar", "Jason Priem"],
        doi: "10.7717/peerj.4375",
        publicationYear: 2018,
        venue: "PeerJ",
        abstract: "Despite growing interest in Open Access...",
        sourceUrl: "https://openalex.org/W1"
    )

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(apiKey: String?? = nil) -> GeminiChatService {
        GeminiChatService(apiKey: apiKey ?? self.apiKey, model: "gemini-3.8-flash",
                          session: MockURLProtocol.makeSession(), bundleIdentifier: "com.example.LiteratureLegends")
    }

    private func bodyJSON(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func json(_ string: String) -> Data { Data(string.utf8) }

    // MARK: Request building

    func testRequestUsesGenerateContentEndpointAndKeyHeader() throws {
        let request = try makeService().makeRequest(question: "What is it about?", paper: paper, history: [])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), apiKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.example.LiteratureLegends")
        // The key must never be in the URL.
        XCTAssertFalse(request.url!.absoluteString.contains(apiKey))
        XCTAssertNil(request.url?.query)
    }

    func testBodyHasSystemInstructionWithPaperContext() throws {
        let body = try bodyJSON(makeService().makeRequest(question: "Q", paper: paper, history: []))
        let system = try XCTUnwrap(body["systemInstruction"] as? [String: Any])
        let parts = try XCTUnwrap(system["parts"] as? [[String: Any]])
        let text = try XCTUnwrap(parts.first?["text"] as? String)

        XCTAssertNil(system["role"])
        XCTAssertTrue(text.contains("research assistant for students"))
        XCTAssertTrue(text.contains("Answer only from the provided paper information"))
        XCTAssertTrue(text.contains("[1]"))
        XCTAssertTrue(text.contains("Title: The state of OA"))
        XCTAssertTrue(text.contains("Authors: Heather Piwowar, Jason Priem"))
        XCTAssertTrue(text.contains("Year: 2018"))
        XCTAssertTrue(text.contains("Venue: PeerJ"))
        XCTAssertTrue(text.contains("DOI: 10.7717/peerj.4375"))
        XCTAssertTrue(text.contains("Link: https://openalex.org/W1"))
        XCTAssertTrue(text.contains("Abstract: Despite growing interest"))
    }

    func testBodyCapsOutputTokensAndSetsThinkingLevel() throws {
        let body = try bodyJSON(makeService().makeRequest(question: "Q", paper: paper, history: []))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["maxOutputTokens"] as? Int, GeminiChatService.maxOutputTokens)
        let thinking = try XCTUnwrap(config["thinkingConfig"] as? [String: Any])
        XCTAssertEqual(thinking["thinkingLevel"] as? String, "LOW")
    }

    func testContentsIncludeHistoryThenQuestionWithGeminiRoles() throws {
        let history = [ChatMessage(role: .user, text: "First?"), ChatMessage(role: .assistant, text: "Answer [1].")]
        let body = try bodyJSON(makeService().makeRequest(question: "Second?", paper: paper, history: history))
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])

        XCTAssertEqual(contents.map { $0["role"] as? String }, ["user", "model", "user"])
        let texts = contents.map { (($0["parts"] as? [[String: Any]])?.first?["text"] as? String) }
        XCTAssertEqual(texts, ["First?", "Answer [1].", "Second?"])
    }

    func testHistoryIsTrimmedAndStartsWithUserTurn() {
        var history: [ChatMessage] = []
        for index in 1...8 {
            history.append(ChatMessage(role: .user, text: "Q\(index)"))
            history.append(ChatMessage(role: .assistant, text: "A\(index)"))
        }
        let trimmed = GeminiChatService.trimmedHistory(history)
        XCTAssertLessThanOrEqual(trimmed.count, GeminiChatService.maxHistoryMessages)
        XCTAssertEqual(trimmed.first?.role, .user)
        XCTAssertEqual(trimmed.last?.text, "A8")

        let startsWithAnswer = [ChatMessage(role: .assistant, text: "A0"), ChatMessage(role: .user, text: "Q1")]
        XCTAssertEqual(GeminiChatService.trimmedHistory(startsWithAnswer).map(\.text), ["Q1"])
    }

    func testMissingFieldsAreLeftOutOfContext() {
        let bare = Paper(externalApiId: "W2", title: "Bare", sourceUrl: "https://openalex.org/W2")
        let context = GeminiChatService.paperContext(bare)
        XCTAssertFalse(context.contains("Authors:"))
        XCTAssertFalse(context.contains("DOI:"))
        XCTAssertTrue(context.contains("Abstract: Not available."))
    }

    // MARK: Missing key

    func testMissingKeyThrowsWithoutNetwork() async {
        let service = makeService(apiKey: .some(nil))
        XCTAssertFalse(service.isConfigured)
        do {
            _ = try await service.answer(question: "Q", about: paper, history: [])
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? ChatError, .missingAPIKey)
        }
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    // MARK: Response parsing

    func testParsesAnswerAndSkipsThoughtParts() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: json("""
        {"candidates":[{"content":{"role":"model","parts":[
            {"text":"internal reasoning","thought":true},
            {"text":"About 28% of articles are OA "},
            {"text":"[1]."}
        ]},"finishReason":"STOP"}],
         "usageMetadata":{"promptTokenCount":120,"candidatesTokenCount":12,"thoughtsTokenCount":30,"totalTokenCount":162}}
        """))

        let reply = try await makeService().answer(question: "Q", about: paper, history: [])
        XCTAssertEqual(reply, ChatReply(text: "About 28% of articles are OA [1].", isTruncated: false))
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testMaxTokensMarksReplyTruncated() throws {
        let reply = try GeminiChatService.parseReply(json("""
        {"candidates":[{"content":{"parts":[{"text":"Partial answer"}]},"finishReason":"MAX_TOKENS"}]}
        """))
        XCTAssertTrue(reply.isTruncated)
        XCTAssertEqual(reply.text, "Partial answer")
    }

    func testBlockedPromptMapsToBlocked() {
        XCTAssertThrowsError(try GeminiChatService.parseReply(json(#"{"promptFeedback":{"blockReason":"SAFETY"}}"#))) {
            XCTAssertEqual($0 as? ChatError, .blocked)
        }
    }

    func testSafetyFinishWithoutTextMapsToBlocked() {
        XCTAssertThrowsError(try GeminiChatService.parseReply(json(#"{"candidates":[{"finishReason":"SAFETY"}]}"#))) {
            XCTAssertEqual($0 as? ChatError, .blocked)
        }
    }

    func testNoCandidatesMapsToEmptyAnswer() {
        XCTAssertThrowsError(try GeminiChatService.parseReply(json(#"{"candidates":[]}"#))) {
            XCTAssertEqual($0 as? ChatError, .emptyAnswer)
        }
    }

    func testMalformedJSONMapsToUnexpectedResponse() {
        XCTAssertThrowsError(try GeminiChatService.parseReply(json("not json"))) {
            XCTAssertEqual($0 as? ChatError, .unexpectedResponse)
        }
    }

    // MARK: Error mapping

    func testRateLimitMapsToQuotaExceeded() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 429, data: json(
            #"{"error":{"code":429,"message":"Resource has been exhausted (e.g. check quota).","status":"RESOURCE_EXHAUSTED"}}"#))
        await assertError(.quotaExceeded)
    }

    func testInvalidKeyMapsToInvalidAPIKey() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 400, data: json(
            #"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}"#))
        await assertError(.invalidAPIKey)
    }

    func testPermissionDeniedMapsToInvalidAPIKey() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 403, data: json(
            #"{"error":{"code":403,"message":"Your API key was reported as leaked.","status":"PERMISSION_DENIED"}}"#))
        await assertError(.invalidAPIKey)
    }

    func testOtherBadRequestMapsToServerError() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 400, data: json(
            #"{"error":{"code":400,"message":"Invalid value at 'contents'","status":"INVALID_ARGUMENT"}}"#))
        await assertError(.server(statusCode: 400))
    }

    func testServerErrorMapsToServer() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 500, data: json("Internal Server Error"))
        await assertError(.server(statusCode: 500))
    }

    func testHighDemand503MapsToServiceBusy() async {
        // Body copied from a live 503 response (2026-11-20).
        MockURLProtocol.handler = MockURLProtocol.respond(status: 503, data: json(
            #"{"error":{"code":503,"message":"This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.","status":"UNAVAILABLE"}}"#))
        await assertError(.serviceBusy)
    }

    func testOfflineMapsToOffline() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .notConnectedToInternet)
        await assertError(.offline)
    }

    func testConnectionLostMapsToOffline() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .networkConnectionLost)
        await assertError(.offline)
    }

    /// Regression: a stalled Gemini request (high demand) timed out and was shown as "You're offline".
    func testTimeoutIsNotOffline() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .timedOut)
        await assertError(.timedOut)
        XCTAssertFalse(ChatError.timedOut.message.contains("offline"))
    }

    func testOtherURLErrorsAreNotOfflineAndKeepTheirCode() async {
        for code: URLError.Code in [.cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed] {
            MockURLProtocol.handler = MockURLProtocol.fail(with: code)
            await assertError(.network(code: code.rawValue))
        }
    }

    func testDebugBuildsShowTheErrorCode() {
        #if DEBUG
        XCTAssertTrue(ChatError.timedOut.message.hasSuffix("[URLError -1001]"))
        XCTAssertTrue(ChatError.network(code: -1003).message.hasSuffix("[URLError -1003]"))
        XCTAssertTrue(ChatError.serviceBusy.message.hasSuffix("[HTTP 503]"))
        #endif
    }

    func testErrorMessagesNeverContainTheKey() {
        let errors: [ChatError] = [.missingAPIKey, .invalidAPIKey, .quotaExceeded, .offline, .timedOut, .serviceBusy,
                                   .network(code: -1004), .blocked, .emptyAnswer, .server(statusCode: 500),
                                   .unexpectedResponse]
        for error in errors {
            XCTAssertFalse(error.message.contains(apiKey))
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    private func assertError(_ expected: ChatError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await makeService().answer(question: "Q", about: paper, history: [])
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ChatError, expected, file: file, line: line)
        }
    }
}
