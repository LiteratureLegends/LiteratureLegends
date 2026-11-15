import Foundation
import Combine

// Feature-specific name avoids colliding with the eventual shared User model.
struct UserProfile {
    let id: String
    var firstName: String
    var lastName: String
    var userName: String
    var email: String
    let createdAt: Date

    var name: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let letters = [firstName, lastName].compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

/// In-memory profile state, ready for an authenticated profile service later.
final class ProfileStore: ObservableObject {
    @Published var profile: UserProfile
    // Supply the real authentication provider's reset-email action at integration.
    let sendPasswordReset: ((String) async throws -> Void)?

    init(profile: UserProfile, sendPasswordReset: ((String) async throws -> Void)? = nil) {
        self.profile = profile
        self.sendPasswordReset = sendPasswordReset
    }
}
