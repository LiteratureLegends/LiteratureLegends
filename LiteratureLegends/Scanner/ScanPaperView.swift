//
//  ScanPaperView.swift
//  LiteratureLegends · Scanner
//
//  "Scan paper" from the Home page: scan with the camera (or import a photo), read the text on
//  device, and look the paper up in OpenAlex. Styled like the Discover/Home page.
//

import PhotosUI
import SwiftUI
import VisionKit

struct ScanPaperView: View {
    @State private var viewModel: ScanPaperViewModel
    @State private var isPresentingScanner = false
    @State private var pickedPhoto: PhotosPickerItem?
    private let searchService: (any PaperSearchService)?
    private let ownerId: String?
    private let projectService: (any ProjectService)?

    init(
        searchService: (any PaperSearchService)?,
        ownerId: String? = nil,
        projectService: (any ProjectService)? = nil
    ) {
        self.searchService = searchService
        self.ownerId = ownerId
        self.projectService = projectService
        _viewModel = State(initialValue: ScanPaperViewModel(service: searchService))
    }

    private var isScannerSupported: Bool {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return false }
        return VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                captureCard

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .card()
                }

                if viewModel.isRecognizing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Reading the image…").foregroundStyle(.secondary)
                    }
                }

                if let result = viewModel.result {
                    resultSections(result)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Scan paper")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isPresentingScanner) {
            DocumentScannerView { scan in
                Task { await viewModel.didScan(scan) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                defer { pickedPhoto = nil }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.didImport(image)
                } else {
                    viewModel.failedToLoadImage()
                }
            }
        }
    }

    // MARK: Capture

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("From page to perspective")
                    .font(.headline)
                Text("Scan the first page of a paper to identify it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isScannerSupported {
                Button {
                    viewModel.reset()
                    isPresentingScanner = true
                } label: {
                    Label(viewModel.result == nil ? "Scan paper" : "Scan another", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            PhotosPicker(selection: $pickedPhoto, matching: .images) {
                Label("Choose a photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            if !isScannerSupported {
                Text("The camera scanner isn't available on this device, but you can still read a photo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Results

    @ViewBuilder
    private func resultSections(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What we found")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Pages", value: "\(result.pageCount)")
                if let doi = result.detectedDOI {
                    LabeledContent("DOI", value: doi)
                        .textSelection(.enabled)
                }
                if result.extractedText.isEmpty {
                    Text("No text was recognized. Try again with better light and the page flat.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    DisclosureGroup("Recognized text") {
                        Text(result.extractedText)
                            .font(.footnote)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
            .card()
        }

        if !result.extractedText.isEmpty {
            matchesSection
        }
    }

    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matching papers")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            HStack {
                TextField("Title or DOI", text: $viewModel.query, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.lookUp() } }
                Button {
                    Task { await viewModel.lookUp() }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search again")
            }
            .card()

            switch viewModel.lookup {
            case .idle:
                EmptyView()
            case .searching:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Looking up this paper…").foregroundStyle(.secondary)
                }
            case .matches(let papers):
                if let searchService {
                    LazyVStack(spacing: 10) {
                        ForEach(papers) { paper in
                            NavigationLink {
                                PaperDetailView(
                                    paper: paper,
                                    service: searchService,
                                    ownerId: ownerId,
                                    projectService: projectService
                                )
                            } label: {
                                PaperRowView(paper: paper)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .card()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            case .noMatches:
                note("No matching papers", "Edit the text above, then search again.", systemImage: "doc.text.magnifyingglass")
            case .failed(let message):
                note("Couldn't look this up", message, systemImage: "exclamationmark.triangle")
            case .unavailable:
                note("Search isn't set up", "Add an OpenAlex key to identify scanned papers.", systemImage: "key")
            }
        }
    }

    private func note(_ title: String, _ message: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

private extension View {
    /// The rounded card used across the Home page.
    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

#Preview {
    NavigationStack {
        ScanPaperView(searchService: MockPaperSearchService())
    }
}
