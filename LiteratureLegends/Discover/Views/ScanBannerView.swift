//
//  ScanBannerView.swift
//  LiteratureLegends · Discover
//
//  "From page to perspective / Scan paper" banner from images/Wireframe2.jpeg.
//

import SwiftUI

struct ScanBannerView: View {
    let searchService: (any PaperSearchService)?
    var ownerId: String?
    var projectService: (any ProjectService)?

    var body: some View {
        NavigationLink {
            ScanPaperView(searchService: searchService, ownerId: ownerId, projectService: projectService)
        } label: {
            bannerContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan paper")
    }

    private var bannerContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "viewfinder")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tint)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("From page to perspective")
                    .font(.headline)
                Text("Scan paper")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

#Preview {
    NavigationStack {
        ScanBannerView(searchService: MockPaperSearchService()).padding()
    }
}
