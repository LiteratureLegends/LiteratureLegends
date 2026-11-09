//
//  PaperRowView.swift
//  LiteratureAssistant · PaperSearch
//

import SwiftUI

/// One search result: title, first three authors (+ "et al."), year, venue, citations.
struct PaperRowView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.title)
                .font(.headline)
                .lineLimit(3)

            Text(paper.shortAuthorList)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let year = paper.displayYear {
                    Text(year)
                }
                if let venue = paper.venue {
                    Text("·")
                    Text(venue)
                        .italic()
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let citationCount = paper.citationCount {
                    Label(citationCount.formatted(), systemImage: "quote.bubble")
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel(paper.citationText ?? "")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        PaperRowView(paper: MockPaperSearchService.sample)
        PaperRowView(paper: MockPaperSearchService.samplePaper(number: 4, query: "sparse"))
        PaperRowView(paper: Paper(externalApiId: "W1", title: "Untitled", sourceUrl: "https://openalex.org/W1"))
    }
    .listStyle(.plain)
}
