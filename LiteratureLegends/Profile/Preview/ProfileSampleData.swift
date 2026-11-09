import Foundation

enum ProfileSampleData {
    static func makeStore() -> ProfileStore {
        ProfileStore(profile: UserProfile(
            id: "sample-user", firstName: "Jamie", lastName: "Lee", userName: "jamielee",
            email: "jamie@example.com", createdAt: Date(timeIntervalSince1970: 1_788_220_800)
        ))
    }
}
