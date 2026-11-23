#if DEBUG
import Foundation

enum ProfileSampleData {
    static let user = AuthUser(id: "sample-user", email: "jamie@example.com", name: "Jamie Lee",
                               username: "jamie@example.com", createdAt: Date(timeIntervalSince1970: 1_788_220_800))
}
#endif
