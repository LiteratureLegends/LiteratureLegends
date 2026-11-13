import Foundation

/// Real Parse Server authentication through its public REST API.
/// No SDK/package dependency; configure ParseConfiguration.swift when ready.
final class ParseAuthService: AuthServicing {
    private let keychain = KeychainSessionStore()
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func register(name: String, email: String, password: String) async throws -> AuthUser {
        let normalizedEmail = AuthValidation.cleanEmail(email)
        try AuthValidation.validateName(name)
        try AuthValidation.validateEmail(normalizedEmail)
        try AuthValidation.validatePassword(password)
        let result: ParseUserResponse = try await request(
            "users", method: "POST",
            body: ["username": normalizedEmail,
                   "email": normalizedEmail,
                   "password": password,
                   "name": name.trimmingCharacters(in: .whitespacesAndNewlines)]
        )
        return try storeAndConvert(result, fallbackEmail: normalizedEmail, fallbackName: name)
    }

    func login(email: String, password: String) async throws -> AuthUser {
        let normalizedEmail = AuthValidation.cleanEmail(email)
        try AuthValidation.validateEmail(normalizedEmail)
        guard !password.isEmpty else { throw AuthFailure.weakPassword }
        // POST keeps the password out of URL query strings and access logs.
        let result: ParseUserResponse = try await request(
            "login", method: "POST",
            body: ["username": normalizedEmail, "password": password]
        )
        return try storeAndConvert(result, fallbackEmail: normalizedEmail)
    }

    func restoreSession() async throws -> AuthUser? {
        guard let token = keychain.read(), !token.isEmpty else { return nil }
        do {
            let result: ParseUserResponse = try await request(
                "users/me", method: "GET", sessionToken: token)
            return result.asUser()
        } catch let error as ParseHTTPError where error.code == 209 {
            // Explicitly invalid/revoked session, not a temporary network issue.
            keychain.clear()
            return nil
        }
    }

    func logout() async throws {
        guard let token = keychain.read(), !token.isEmpty else { return }
        // Keep the local token if remote revocation fails, so we can retry.
        let _: EmptyParseResponse = try await request(
            "logout", method: "POST", sessionToken: token)
        keychain.clear()
    }

    private func storeAndConvert(
        _ response: ParseUserResponse,
        fallbackEmail: String,
        fallbackName: String = ""
    ) throws -> AuthUser {
        guard let token = response.sessionToken, !token.isEmpty else {
            throw AuthFailure.missingSession
        }
        try keychain.write(token)
        return response.asUser(fallbackEmail: fallbackEmail, fallbackName: fallbackName)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        body: [String: String]? = nil,
        sessionToken: String? = nil
    ) async throws -> T {
        guard let baseURL = ParseConfiguration.baseURL else {
            throw AuthFailure.notConfigured
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(ParseConfiguration.applicationID, forHTTPHeaderField: "X-Parse-Application-Id")
        request.setValue("1", forHTTPHeaderField: "X-Parse-Revocable-Session")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = ParseConfiguration.restAPIKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Parse-REST-API-Key")
        }
        if let sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Parse-Session-Token")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthFailure.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else {
            if let parseError = try? JSONDecoder().decode(ParseHTTPError.self, from: data) {
                throw parseError
            }
            throw AuthFailure.server("Server error (HTTP \(http.statusCode)).")
        }
        do {
            // Parse /logout may return {} or an empty body.
            return try JSONDecoder().decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw AuthFailure.unexpectedResponse
        }
    }
}

private struct ParseUserResponse: Decodable {
    let objectId: String
    let username: String?
    let email: String?
    let name: String?
    let sessionToken: String?

    func asUser(fallbackEmail: String = "", fallbackName: String = "") -> AuthUser {
        AuthUser(id: objectId,
                 email: email ?? username ?? fallbackEmail,
                 name: name ?? (fallbackName.isEmpty ? "Student" : fallbackName))
    }
}

private struct EmptyParseResponse: Decodable {}

private struct ParseHTTPError: Decodable, LocalizedError {
    let code: Int
    let error: String

    var errorDescription: String? {
        switch code {
        case 101: return "Incorrect email or password."
        case 202, 203: return "An account with this email already exists."
        case 209: return "Your session has expired. Please log in again."
        default: return error
        }
    }
}
