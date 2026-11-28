//
//  ScanPaperViewModelTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

@MainActor
final class ScanPaperViewModelTests: XCTestCase {
    func testSuggestedQueryPrefersDOIAndTrimsPunctuation() {
        let text = "Deep Learning\nSee https://doi.org/10.1038/nature14539."
        let scan = ScanResult(pageCount: 1, extractedText: text, detectedDOI: ScanResult.detectDOI(in: text))
        XCTAssertEqual(ScanPaperViewModel.suggestedQuery(for: scan), "10.1038/nature14539")
    }

    func testSuggestedQueryFallsBackToFirstLines() {
        let scan = ScanResult(
            pageCount: 1,
            extractedText: "Attention Is All\nYou Need\n\nA. Author\nAbstract",
            detectedDOI: nil
        )
        XCTAssertEqual(ScanPaperViewModel.suggestedQuery(for: scan), "Attention Is All You Need A. Author")
    }

    func testScanWithTextLooksUpMatches() async {
        let viewModel = ScanPaperViewModel(service: MockPaperSearchService(delay: .zero))
        let scan = ScanResult(pageCount: 1, extractedText: "Graph neural networks", detectedDOI: nil)
        await viewModel.didScan(.success(scan))

        XCTAssertEqual(viewModel.query, "Graph neural networks")
        guard case .matches(let papers) = viewModel.lookup else {
            return XCTFail("Expected matches, got \(viewModel.lookup)")
        }
        XCTAssertFalse(papers.isEmpty)
        XCTAssertLessThanOrEqual(papers.count, 5)
    }

    func testScanWithoutSearchServiceIsUnavailable() async {
        let viewModel = ScanPaperViewModel(service: nil)
        let scan = ScanResult(pageCount: 1, extractedText: "Some title", detectedDOI: nil)
        await viewModel.didScan(.success(scan))
        XCTAssertEqual(viewModel.lookup, .unavailable)
    }

    func testEmptyScanSkipsLookup() async {
        let viewModel = ScanPaperViewModel(service: MockPaperSearchService(delay: .zero))
        await viewModel.didScan(.success(ScanResult(pageCount: 1, extractedText: "", detectedDOI: nil)))
        XCTAssertEqual(viewModel.lookup, .noMatches)
    }

    func testScanFailureShowsMessage() async {
        let viewModel = ScanPaperViewModel(service: nil)
        await viewModel.didScan(.failure(URLError(.cancelled)))
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.result)
    }
}
