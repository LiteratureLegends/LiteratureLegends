//
//  ScanBannerView.swift
//  LiteratureLegends · Discover
//
//  "From page to perspective / Scan paper" banner from images/Wireframe2.jpeg.
//

import SwiftUI

struct ScanBannerView: View {
    var body: some View {
        // TODO: Link ScannerView once Andrei's scanner is merged into main, e.g.
        // NavigationLink { ScannerView() } label: { bannerContent }, and drop .disabled/"Coming soon".
        Button {} label: { bannerContent }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Scan paper, coming soon")
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

            Text("Coming soon")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }
}

#Preview {
    ScanBannerView().padding()
}
