//
//  AppConfig.swift
//  LiteratureAssistant
//
//  Reads build-time configuration that Config/App.xcconfig injects into Info.plist.
//

import Foundation

nonisolated enum AppConfig {
    static let openAlexAPIKeyInfoKey = "OpenAlexAPIKey"
    static let placeholderAPIKey = "YOUR_OPENALEX_API_KEY"

    /// The OpenAlex API key, or nil if it's missing or still the placeholder.
    static var openAlexAPIKey: String? {
        sanitizedAPIKey(Bundle.main.object(forInfoDictionaryKey: openAlexAPIKeyInfoKey) as? String)
    }

    static func sanitizedAPIKey(_ raw: String?) -> String? {
        guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key != placeholderAPIKey,
              !key.hasPrefix("$(") // build setting was never substituted
        else { return nil }
        return key
    }
}
