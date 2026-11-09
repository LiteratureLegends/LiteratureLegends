//
//  MissingAPIKeyView.swift
//  LiteratureAssistant · PaperSearch
//

import SwiftUI

/// Shown instead of Discover when no OpenAlex key is configured, so the app never crashes.
struct MissingAPIKeyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("OpenAlex API key needed", systemImage: "key.slash")
        } description: {
            VStack(spacing: 8) {
                Text("Paper search needs a free OpenAlex API key.")
                Text("1. Get a key at openalex.org/settings/api\n2. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig\n3. Paste your key as OPENALEX_API_KEY, then clean and rebuild")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

#Preview {
    MissingAPIKeyView()
}
