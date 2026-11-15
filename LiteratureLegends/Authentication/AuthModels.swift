import Foundation

/// Authentication data returned by the server. No passwords are stored in the app.
struct AuthUser: Equatable {
    let id: String
    let email: String
    let name: String
}

enum AuthFailure: LocalizedError {
    case notConfigured
    case invalidEmail
    case weakPassword
    case missingName
    case passwordsDoNotMatch
    case missingSession
    case unexpectedResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The Parse backend hasn't been configured yet. Ask the team for the server URL and application ID."
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Use a password with at least 8 characters."
        case .missingName:
            return "Enter your name."
        case .passwordsDoNotMatch:
            return "The passwords don't match."
        case .missingSession:
            return "The server did not return an authentication session."
        case .unexpectedResponse:
            return "An unexpected response was received. Please try again."
        case .server(let message):
            return message
        }
    }
}

enum AuthValidation {
    static func cleanEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func validateEmail(_ email: String) throws {
        // Lightweight client-side feedback. The backend still validates input.
        let regex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard email.range(of: regex, options: .regularExpression) != nil else {
            throw AuthFailure.invalidEmail
        }
    }

    static func validatePassword(_ password: String) throws {
        guard password.count >= 8 else { throw AuthFailure.weakPassword }
    }

    static func validateName(_ name: String) throws {
        guard name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            throw AuthFailure.missingName
        }
    }
}

protocol AuthServicing {
    func register(name: String, email: String, password: String) async throws -> AuthUser
    func login(email: String, password: String) async throws -> AuthUser
    func restoreSession() async throws -> AuthUser?
    func logout() async throws
}
