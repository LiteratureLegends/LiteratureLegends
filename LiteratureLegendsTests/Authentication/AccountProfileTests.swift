import XCTest
@testable import LiteratureLegends

final class AccountProfileTests: XCTestCase {
    private func account(_ json: String) throws -> ParseUserResponse {
        try JSONDecoder().decode(ParseUserResponse.self, from: Data(json.utf8))
    }

    func testMapsStoredAccountFields() throws {
        let account = try account(#"{"objectId":"123","name":"Ada Lovelace","username":"ada","email":"ada@example.org","createdAt":"2025-02-10T15:45:00.123Z"}"#)
        let user = account.asUser()
        XCTAssertEqual(user.id, "123")
        XCTAssertEqual(user.displayName, "Ada Lovelace")
        XCTAssertEqual(user.username, "ada")
        XCTAssertEqual(user.email, "ada@example.org")
        XCTAssertNotNil(user.createdAt)
    }

    func testRegistrationResponseUsesSubmittedFields() throws {
        let response = try account(#"{"objectId":"321","createdAt":"2024-03-19T01:02:03Z"}"#)
        let user = response.asUser(fallbackEmail: "rui@example.org", fallbackName: "Rui")
        XCTAssertEqual(user.displayName, "Rui")
        XCTAssertEqual(user.email, "rui@example.org")
        XCTAssertEqual(user.username, "rui@example.org")
        XCTAssertNotNil(user.createdAt)
    }

    func testOlderAccountUsesAvailableIdentity() throws {
        let response = try account(#"{"objectId":"456","username":"other@example.org"}"#)
        let user = response.asUser()
        XCTAssertEqual(user.displayName, "other@example.org")
        XCTAssertEqual(user.email, "other@example.org")
        XCTAssertNil(user.createdAt)
    }
}
