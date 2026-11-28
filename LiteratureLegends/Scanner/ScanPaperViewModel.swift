//
//  ScanPaperViewModel.swift
//  LiteratureLegends · Scanner
//
//  Turns a scan (or imported photo) into text, then looks the paper up in OpenAlex:
//  by DOI when one is printed on the page, otherwise by the title lines.
//

import Observation
import UIKit

@MainActor
@Observable
final class ScanPaperViewModel {
    enum Lookup: Equatable {
        case idle
        case searching
        case matches([Paper])
        case noMatches
        case failed(String)
        /// No OpenAlex key is configured, so only the recognized text is shown.
        case unavailable
    }

    private(set) var result: ScanResult?
    private(set) var isRecognizing = false
    private(set) var lookup: Lookup = .idle
    private(set) var errorMessage: String?
    /// What gets searched; prefilled from the scan and editable by the user.
    var query = ""

    private let service: (any PaperSearchService)?
    private let maxMatches = 5

    init(service: (any PaperSearchService)?) {
        self.service = service
    }

    /// Result from the document camera.
    func didScan(_ scan: Result<ScanResult, Error>) async {
        switch scan {
        case .success(let value): await show(value)
        case .failure(let error): errorMessage = "Scan failed: \(error.localizedDescription)"
        }
    }

    /// An image picked from the photo library.
    func didImport(_ image: UIImage) async {
        errorMessage = nil
        isRecognizing = true
        defer { isRecognizing = false }
        do {
            let text = try await TextRecognizer.recognizeText(in: [image])
            await show(ScanResult(pageCount: 1, extractedText: text, detectedDOI: ScanResult.detectDOI(in: text)))
        } catch {
            errorMessage = "Couldn't read that image: \(error.localizedDescription)"
        }
    }

    func failedToLoadImage() {
        errorMessage = "Couldn't load that photo."
    }

    func reset() {
        result = nil
        query = ""
        lookup = .idle
        errorMessage = nil
    }

    func lookUp() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { lookup = .noMatches; return }
        guard let service else { lookup = .unavailable; return }

        lookup = .searching
        let mode = SearchMode.effectiveMode(for: trimmed, selected: .keyword)
        do {
            let page = try await service.searchPapers(query: trimmed, mode: mode, page: 1)
            guard !Task.isCancelled else { return }
            lookup = page.papers.isEmpty ? .noMatches : .matches(Array(page.papers.prefix(maxMatches)))
        } catch is CancellationError {
            return
        } catch {
            lookup = .failed(PaperSearchError(error).message)
        }
    }

    private func show(_ scan: ScanResult) async {
        errorMessage = nil
        result = scan
        query = Self.suggestedQuery(for: scan)
        guard !scan.extractedText.isEmpty else { lookup = .noMatches; return }
        await lookUp()
    }

    /// The DOI if the page has one, otherwise the first few text lines (usually the title).
    static func suggestedQuery(for scan: ScanResult) -> String {
        if let doi = scan.detectedDOI {
            // The DOI pattern can swallow trailing punctuation from the sentence it sits in.
            return doi.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)]}"))
        }
        let lines = scan.extractedText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 2 }
        return String(lines.prefix(3).joined(separator: " ").prefix(160))
    }
}
