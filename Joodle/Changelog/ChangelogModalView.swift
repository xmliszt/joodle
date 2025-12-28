//
//  ChangelogModalView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// Modal view displayed automatically when user updates to a new version
struct ChangelogModalView: View {
    let entry: ChangelogEntry
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        ChangelogManager.shared.markCurrentVersionAsSeen()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.appTextPrimary)
                    }
                }
            }
        }
    }
}

#Preview {
    ChangelogModalView(
        entry: ChangelogEntry(
            version: "1.0.55",
            major: 1,
            minor: 0,
            build: 55,
            date: Date(),
            headerImageURL: URL(string: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Joodle%20Icon%20Light.jpg"),
            markdownContent: """
            ## ✨ What's New

            - **New Feature**: Something amazing
            - **Improvement**: Made things better

            ## 🐛 Bug Fixes

            - Fixed a crash
            - Fixed another issue
            """
        ),
        onDismiss: {}
    )
}
