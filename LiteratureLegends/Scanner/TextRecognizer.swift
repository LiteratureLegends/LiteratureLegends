//
//  TextRecognizer.swift
//  LiteratureLegends · Scanner
//
//  On-device OCR shared by the document camera and the photo importer.
//

import UIKit
import Vision

enum TextRecognizer {
    /// Recognizes the text on each image (one block per page, pages separated by a blank line).
    static func recognizeText(in images: [UIImage]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            var pages: [String] = []
            for image in images {
                guard let cgImage = image.cgImage else { continue }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .init(image.imageOrientation), options: [:])
                try handler.perform([request])

                let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                if !lines.isEmpty {
                    pages.append(lines.joined(separator: "\n"))
                }
            }
            return pages.joined(separator: "\n\n")
        }.value
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
