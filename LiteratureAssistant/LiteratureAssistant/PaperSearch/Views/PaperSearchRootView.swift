//
//  PaperSearchRootView.swift
//  LiteratureAssistant · PaperSearch
//
//  Entry point for the feature. Its only dependency on the app target is
//  `AppConfig.openAlexAPIKey` (see PORTING.md).
//

import SwiftUI

struct PaperSearchRootView: View {
    private let apiKey: String?

    init(apiKey: String? = AppConfig.openAlexAPIKey) {
        self.apiKey = apiKey
    }

    var body: some View {
        if let apiKey {
            DiscoverView(service: OpenAlexService(apiKey: apiKey))
        } else {
            MissingAPIKeyView()
        }
    }
}

#Preview("Missing key") {
    PaperSearchRootView(apiKey: nil)
}
