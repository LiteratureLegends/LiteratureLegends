//
//  MockURLProtocol.swift
//  LiteratureAssistantTests
//
//  Intercepts every request made through `MockURLProtocol.makeSession()` so tests never
//  touch the real network. Set `MockURLProtocol.handler` before each test.
//

import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: Handler?
    nonisolated(unsafe) private static var _requests: [URLRequest] = []

    static var handler: Handler? {
        get { lock.withLock { _handler } }
        set { lock.withLock { _handler = newValue } }
    }

    /// Every request seen since the last `reset()`, in order.
    static var requests: [URLRequest] {
        lock.withLock { _requests }
    }

    static func reset() {
        lock.withLock {
            _handler = nil
            _requests = []
        }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: Convenience handlers

    static func respond(status: Int = 200, data: Data, headers: [String: String] = [:]) -> Handler {
        { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            return (response, data)
        }
    }

    static func fail(with code: URLError.Code) -> Handler {
        { _ in throw URLError(code) }
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.lock.withLock { () -> Handler? in
            Self._requests.append(request)
            return Self._handler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
