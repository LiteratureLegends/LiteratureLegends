import Foundation

struct ScanResult {
    let pageCount: Int
    let extractedText: String
    let detectedDOI: String?

    var titleCandidate: String? {
        extractedText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

extension ScanResult {
    static func detectDOI(in text: String) -> String? {
        let pattern = #"10\.\d{4,9}/[-._;()/:A-Z0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }

        return String(text[swiftRange])
    }
}
