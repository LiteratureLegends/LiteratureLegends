import SwiftUI
import VisionKit

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
            // Close the camera right away; recognition continues while the caller shows progress.
            controller.dismiss(animated: true)

            Task { @MainActor in
                do {
                    let extractedText = try await TextRecognizer.recognizeText(in: images)
                    let result = ScanResult(
                        pageCount: pageCount,
                        extractedText: extractedText,
                        detectedDOI: ScanResult.detectDOI(in: extractedText)
                    )
                    onCompletion(.success(result))
                } catch {
                    onCompletion(.failure(error))
                }
            }
        }
    }
}
