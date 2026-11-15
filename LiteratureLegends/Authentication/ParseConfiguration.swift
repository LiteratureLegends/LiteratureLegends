import Foundation

/// Only public Parse client configuration goes here, NEVER a Parse master key.
/// Ask the team's backend owner for the actual server URL and application ID.
/// Example server URL: https://your-server.example/parse
/// The placeholder configuration intentionally prevents live authentication.
enum ParseConfiguration {
    static let serverURLString = "https://YOUR_PARSE_SERVER.example/parse"
    static let applicationID = "YOUR_PARSE_APPLICATION_ID"

    // Only use a REST API key if your server specifically requires one.
    // Never add a master key to the iOS application.
    static let restAPIKey: String? = nil

    static var isConfigured: Bool {
        guard let url = URL(string: serverURLString),
              url.scheme == "https",
              url.host != nil,
              !serverURLString.contains("YOUR_PARSE_SERVER"),
              !applicationID.isEmpty,
              !applicationID.contains("YOUR_PARSE_APPLICATION_ID") else {
            return false
        }
        return true
    }

    static var baseURL: URL? {
        guard isConfigured else { return nil }
        return URL(string: serverURLString)
    }
}
