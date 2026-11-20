//
//  AppConfig.swift
//  LiteratureLegends
//
//  Reads build-time configuration that Config/App.xcconfig (and the gitignored
//  Config/Secrets.xcconfig) inject into Info.plist. Never log these values.
//

import Foundation

enum AppConfig {
    static let openAlexAPIKeyInfoKey = "OpenAlexAPIKey"
    static let geminiAPIKeyInfoKey = "GeminiAPIKey"
    static let geminiModelInfoKey = "GeminiModel"
    static let parseServerURLInfoKey = "ParseServerURL"
    static let parseApplicationIDInfoKey = "ParseApplicationID"
    static let parseRESTAPIKeyInfoKey = "ParseRESTAPIKey"

    static let placeholderAPIKey = "YOUR_OPENALEX_API_KEY"
    static let defaultGeminiModel = "gemini-3.8-flash"

    /// The OpenAlex API key, or nil if it's missing or still the placeholder.
    static var openAlexAPIKey: String? { value(for: openAlexAPIKeyInfoKey) }

    /// The Gemini API key, or nil if it's missing or still the placeholder.
    static var geminiAPIKey: String? { value(for: geminiAPIKeyInfoKey) }

    /// Gemini model id from App.xcconfig (`GEMINI_MODEL`).
    static var geminiModel: String { value(for: geminiModelInfoKey) ?? defaultGeminiModel }

    static var parseServerURL: String? { value(for: parseServerURLInfoKey) }
    static var parseApplicationID: String? { value(for: parseApplicationIDInfoKey) }
    static var parseRESTAPIKey: String? { value(for: parseRESTAPIKeyInfoKey) }

    static func value(for infoKey: String, in bundle: Bundle = .main) -> String? {
        sanitizedAPIKey(bundle.object(forInfoDictionaryKey: infoKey) as? String)
    }

    /// Trims the value; returns nil when it's empty, a `YOUR_…` placeholder, or an unsubstituted `$(…)`.
    static func sanitizedAPIKey(_ raw: String?) -> String? {
        guard let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key != placeholderAPIKey,
              !key.hasPrefix("YOUR_"),
              !key.hasPrefix("$(") // build setting was never substituted
        else { return nil }
        return key
    }
}
