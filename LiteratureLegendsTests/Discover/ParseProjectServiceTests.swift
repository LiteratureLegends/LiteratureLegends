//
//  ParseProjectServiceTests.swift
//  LiteratureLegendsTests
//
//  All requests go through MockURLProtocol; nothing touches the network or the Keychain.
//

import XCTest
@testable import LiteratureLegends

final class ParseProjectServiceTests: XCTestCase {
    private let settings = ParseRESTSettings(baseURL: URL(string: "https://parseapi.back4app.com")!,
                                             applicationID: "TEST_APP_ID",
                                             restAPIKey: "TEST_REST_KEY")

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeService(settings: ParseRESTSettings?? = nil, token: String? = "r:TEST_SESSION") -> ParseProjectService {
        ParseProjectService(settings: settings ?? self.settings,
                            session: MockURLProtocol.makeSession(),
                            sessionToken: { token })
    }

    private func json(_ string: String) -> Data { Data(string.utf8) }

    // MARK: Request

    func testRequestQueriesOwnersProjectsNewestFirst() throws {
        let request = try makeService().makeRequest(ownerId: "user123", limit: 5)
        let url = try XCTUnwrap(request.url)

        XCTAssertEqual(url.host, "parseapi.back4app.com")
        XCTAssertEqual(url.path, "/classes/Project")
        XCTAssertEqual(request.httpMethod, "GET")
        let query = url.queryDictionary
        XCTAssertEqual(query["where"], #"{"ownerId":"user123"}"#)
        XCTAssertEqual(query["order"], "-updatedAt")
        XCTAssertEqual(query["limit"], "5")
        XCTAssertEqual(query["keys"], "name,ownerId,updatedAt")
    }

    func testRequestSendsPublicKeysAndSessionTokenButNoMasterKey() throws {
        let request = try makeService().makeRequest(ownerId: "u", limit: 5)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Parse-Application-Id"), "TEST_APP_ID")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Parse-REST-API-Key"), "TEST_REST_KEY")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Parse-Session-Token"), "r:TEST_SESSION")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Parse-Master-Key"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Parse-Javascript-Key"))
        XCTAssertFalse(request.url!.absoluteString.contains("TEST_REST_KEY"))
    }

    func testOwnerIdIsJSONEncodedNotInterpolated() throws {
        let request = try makeService().makeRequest(ownerId: #"a"b"#, limit: 5)
        XCTAssertEqual(request.url?.queryDictionary["where"], #"{"ownerId":"a\"b"}"#)
    }

    func testMissingConfigurationThrowsNotConfiguredWithoutNetwork() async {
        let service = makeService(settings: .some(nil))
        do {
            _ = try await service.recentProjects(ownerId: "u", limit: 5)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? ProjectServiceError, .notConfigured)
        }
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testMissingSessionTokenThrowsNotLoggedIn() async {
        do {
            _ = try await makeService(token: nil).recentProjects(ownerId: "u", limit: 5)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? ProjectServiceError, .notLoggedIn)
        }
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    // MARK: Response

    func testParsesResultsInServerOrder() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: json("""
        {"results":[
          {"objectId":"p2","name":"Newest","ownerId":"u","updatedAt":"2026-11-20T18:24:31.123Z"},
          {"objectId":"p1","name":"  ","ownerId":"u","updatedAt":"2026-11-01T08:00:00Z"},
          {"objectId":"p0","ownerId":"u"}
        ]}
        """))

        let projects = try await makeService().recentProjects(ownerId: "u", limit: 5)

        XCTAssertEqual(projects.map(\.id), ["p2", "p1", "p0"])
        XCTAssertEqual(projects[0].name, "Newest")
        XCTAssertEqual(projects[1].name, "Untitled project")
        XCTAssertEqual(projects[0].updatedAt?.timeIntervalSince1970 ?? 0, 1_795_199_071.123, accuracy: 0.001)
        XCTAssertNotNil(projects[1].updatedAt)
        XCTAssertNil(projects[2].updatedAt)
    }

    func testEmptyResults() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: json(#"{"results":[]}"#))
        let projects = try await makeService().recentProjects(ownerId: "u", limit: 5)
        XCTAssertTrue(projects.isEmpty)
    }

    // MARK: Errors

    func testInvalidSessionMapsToSessionExpired() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 400, data: json(#"{"code":209,"error":"Invalid session token"}"#))
        await assertError(.sessionExpired)
    }

    func testServerErrorKeepsStatusCode() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 503, data: json("Service Unavailable"))
        await assertError(.server(statusCode: 503))
    }

    func testOfflineMapsToOffline() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .notConnectedToInternet)
        await assertError(.offline)
    }

    func testMalformedBodyMapsToUnexpectedResponse() async {
        MockURLProtocol.handler = MockURLProtocol.respond(data: json(#"{"oops":true}"#))
        await assertError(.unexpectedResponse)
    }

    func testOnlyNotConfiguredIsNotRetryable() {
        XCTAssertFalse(ProjectServiceError.notConfigured.isRetryable)
        XCTAssertTrue(ProjectServiceError.offline.isRetryable)
        XCTAssertTrue(ProjectServiceError.server(statusCode: 500).isRetryable)
    }

    private func assertError(_ expected: ProjectServiceError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await makeService().recentProjects(ownerId: "u", limit: 5)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ProjectServiceError, expected, file: file, line: line)
        }
    }
}
