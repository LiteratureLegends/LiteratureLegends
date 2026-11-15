import SwiftUI
import VisionKit

struct ScannerView: View {
    @State private var isPresentingScanner = false
    @State private var result: ScanResult?
    @State private var errorMessage: String?

    private var isScannerSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        List {
            Section("Document scanner") {
                if isScannerSupported {
                    Button {
                        errorMessage = nil
                        isPresentingScanner = true
                    } label: {
                        Label("Scan document", systemImage: "camera.viewfinder")
                    }
                } else {
                    Label(
                        "Scanner is unavailable on this device.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.secondary)
                }
            }

            if let result {
                Section("Latest scan") {
                    LabeledContent("Pages", value: "\(result.pageCount)")

                    if let title = result.titleCandidate {
                        LabeledContent("Detected title", value: title)
                    }

                    if let doi = result.detectedDOI {
                        LabeledContent("Detected DOI", value: doi)
                            .textSelection(.enabled)
                    }

                    if result.extractedText.isEmpty {
                        Text("No text was recognized from the scan.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(result.extractedText)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .lineLimit(12)
                    }
                }

                Section {
                    Button("Start conversation about this scan") {
                        // Hook this action into the document chat feature when available.
                    }
                    .disabled(result.extractedText.isEmpty)

                    Button("Add scan to project") {
                        // Hook this action into the project save flow when available.
                    }
                    .disabled(result.extractedText.isEmpty)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Scanner")
        .sheet(isPresented: $isPresentingScanner) {
            DocumentScannerView { scanResult in
                switch scanResult {
                case .success(let value):
                    result = value
                case .failure(let error):
                    errorMessage = "Scan failed: \(error.localizedDescription)"
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    NavigationStack {
        ScannerView()
    }
}
