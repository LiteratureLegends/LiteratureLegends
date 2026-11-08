// xcode: set sdk=iOS

import SwiftUI

struct ContentView: View {
    @State private var query = ""
    @State private var submittedQuery: String?
    @FocusState private var isSearchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                TextField("Search literature", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onSubmit(search)

                Button("Search", action: search)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedQuery.isEmpty)
            }

            if let submittedQuery {
                Text("You searched for: \(submittedQuery)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("searchConfirmation")
            }
        }
        .padding()
    }

    private func search() {
        guard !trimmedQuery.isEmpty else { return }
        submittedQuery = trimmedQuery
        isSearchFocused = false
    }
}

#Preview {
    ContentView()
}
