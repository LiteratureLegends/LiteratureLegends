import SwiftUI
import VisionKit
import Vision

struct DocumentScannerView: UIViewControllerRepresentable {
    let onCompletion: (Result<ScanResult, Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onCompletion: (Result<ScanResult, Error>) -> Void

        init(onCompletion: @escaping (Result<ScanResult, Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onCompletion(.failure(error))
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pageCount = scan.pageCount
            let images = (0..<pageCount).map { scan.imageOfPage(at: $0) }

            Task {
                do {
                    let extractedText = try await recognizeText(in: images)
                    let result = ScanResult(
                        pageCount: pageCount,
                        extractedText: extractedText,
                        detectedDOI: ScanResult.detectDOI(in: extractedText)
                    )
                    onCompletion(.success(result))
                } catch {
                    onCompletion(.failure(error))
                }
                await MainActor.run {
                    controller.dismiss(animated: true)
                }
            }
        }

        private func recognizeText(in images: [UIImage]) async throws -> String {
            var combinedText: [String] = []

            for image in images {
                guard let cgImage = image.cgImage else { continue }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                let lines = request.results?
                    .compactMap { observation in
                        observation.topCandidates(1).first?.string
                    } ?? []

                if !lines.isEmpty {
                    combinedText.append(lines.joined(separator: "\n"))
                }
            }

            return combinedText.joined(separator: "\n\n")
        }
    }
}
