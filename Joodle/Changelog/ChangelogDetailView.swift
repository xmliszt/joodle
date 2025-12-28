//
//  ChangelogDetailView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// Detail view for a single changelog entry, used in Settings navigation
struct ChangelogDetailView: View {
    let entry: ChangelogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and version
                Text(entry.displayHeader)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                // Optional Header Image
                if let imageURL = entry.headerImageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            EmptyView()
                        case .empty:
                            ProgressView()
                                .frame(height: 200)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Markdown Content
                Text(LocalizedStringKey(entry.markdownContent))
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle(entry.displayVersion)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.55",
                major: 1,
                minor: 0,
                build: 55,
                date: Date(),
                headerImageURL: nil,
                markdownContent: """
                ## ✨ What's New

                - **Feature 1**: Description of feature 1
                - **Feature 2**: Description of feature 2

                ## 🐛 Bug Fixes

                - Fixed an issue with sync
                - Improved performance
                """
            )
        )
    }
}
