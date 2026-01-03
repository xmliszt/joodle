//
//  ChangelogDetailView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI
import MarkdownUI

/// Detail view for a single changelog entry, used in Settings navigation
struct ChangelogDetailView: View {
    let entry: ChangelogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and version
              VStack(alignment: .leading) {
                  Text(entry.displayHeader)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                }

                // Optional Header Image
                if let imageURL = entry.headerImageURL {
                    AnimatedImageView(url: imageURL)
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding()
                }

                // Markdown Content
                Markdown(entry.markdownContent)
                .markdownTheme(.docC)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

#Preview ("Without Image") {
    NavigationStack {
      ZStack {
        Color.gray
        .edgesIgnoringSafeArea(.all)
        
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURL: nil,
                markdownContent: """
                ## ✨ What's New

                - **Feature 1**: Description of feature 1
                - **Feature 2**: Description of feature 2

                ---
                ## 🐛 Bug Fixes

                - Fixed an issue with sync
                - Improved performance
                """
            )
        )
      }
       
    }
}


#Preview ("With Image") {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURL: URL(string: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Changelogs/1.0.58.png"),
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
