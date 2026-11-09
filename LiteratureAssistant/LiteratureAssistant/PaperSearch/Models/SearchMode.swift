//
//  SearchMode.swift
//  LiteratureAssistant · PaperSearch
//

import Foundation

nonisolated enum SearchMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case keyword
    case topic
    case author
    case doi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyword: "Keyword"
        case .topic: "Topic"
        case .author: "Author"
        case .doi: "DOI"
        }
    }

    /// The mode actually used for `input`: anything that looks like a DOI is searched as one,
    /// whatever the picker says.
    static func effectiveMode(for input: String, selected: SearchMode) -> SearchMode {
        looksLikeDOI(input) ? .doi : selected
    }

    /// True when the input starts with "10." or mentions doi.org (also accepts a "doi:" prefix).
    static func looksLikeDOI(_ input: String) -> Bool {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text.hasPrefix("10.") || text.contains("doi.org") || text.hasPrefix("doi:")
    }

    /// Extracts the bare DOI ("10.xxxx/yyy") from inputs such as
    /// "https://doi.org/10.1/abc", "doi:10.1/abc" or " 10.1/abc ". Returns nil if none is found.
    static func normalizeDOI(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "doi.org/", options: .caseInsensitive) {
            text = String(text[range.upperBound...])
        } else if text.lowercased().hasPrefix("doi:") {
            text = String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        text = text.removingPercentEncoding ?? text
        guard text.hasPrefix("10."), text.contains("/"),
              let slash = text.firstIndex(of: "/"), text.index(after: slash) < text.endIndex
        else { return nil }
        return text
    }
}
