import Foundation

/// Only public Parse client configuration goes here, NEVER a Parse master key.
/// Values come from Info.plist, injected by Config/App.xcconfig (server URL) and the
/// gitignored Config/Secrets.xcconfig (application ID, REST API key). See readme.md › Developer Setup.
/// Missing or placeholder values intentionally prevent live authentication.
enum ParseConfiguration {
    static let serverURLString = AppConfig.parseServerURL ?? ""
    static let applicationID = AppConfig.parseApplicationID ?? ""

    // Back4App requires the REST API key on every REST request.
    // Never add a master key to the iOS application.
    static let restAPIKey: String? = AppConfig.parseRESTAPIKey

    static var isConfigured: Bool {
        guard let url = URL(string: serverURLString),
              url.scheme == "https",
              url.host != nil,
              !serverURLString.contains("YOUR_PARSE_SERVER"),
              !applicationID.isEmpty,
              !applicationID.contains("YOUR_PARSE_APPLICATION_ID"),
              // Back4App rejects REST calls without X-Parse-REST-API-Key, so treat it as required.
              let restAPIKey, !restAPIKey.isEmpty else {
            return false
        }
        return true
    }

    static var baseURL: URL? {
        guard isConfigured else { return nil }
        return URL(string: serverURLString)
    }
}
