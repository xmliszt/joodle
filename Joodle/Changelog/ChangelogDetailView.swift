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
        content
            .onAppear {
                // Track changelog viewed
                AnalyticsManager.shared.trackChangelogViewed(version: entry.version)
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and version
              VStack(alignment: .leading) {
                  Text(entry.displayHeader)
                    .font(.appCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                }

                // Optional Header Images (hidden when empty)
                if !entry.headerImageURLs.isEmpty {
                    HeaderImageCarouselView(urls: entry.headerImageURLs)
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .center)
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
                headerImageURLs: [],
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


// MARK: - Header Image Carousel

/// Auto-scrolling carousel of header images for a changelog entry.
/// Hides page indicators when there is only one image.
struct HeaderImageCarouselView: View {
    let urls: [URL]
    var autoScrollInterval: TimeInterval = 3.0

    @State private var currentIndex = 0
    @State private var autoScrollTimer: Timer?

    var body: some View {
        if urls.count == 1, let url = urls.first {
            imageView(url: url)
        } else {
            VStack(spacing: 12) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                        imageView(url: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 200)
                .onAppear { startAutoScroll() }
                .onDisappear { stopAutoScroll() }
                .onChange(of: currentIndex) { _, _ in restartAutoScroll() }

                PageIndicatorView(totalPages: urls.count, currentPage: currentIndex)
            }
        }
    }

    private func imageView(url: URL) -> some View {
        AnimatedImageView(url: url)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func startAutoScroll() {
        guard urls.count > 1, autoScrollInterval > 0 else { return }
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = (currentIndex + 1) % urls.count
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func restartAutoScroll() {
        stopAutoScroll()
        startAutoScroll()
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
                headerImageURLs: [
                    URL(string: "https://raw.githubusercontent.com/xmliszt/resources/refs/heads/main/joodle/1.17.png")!
                ],
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

#Preview ("With Multiple Images") {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURLs: [
                    URL(string: "https://raw.githubusercontent.com/xmliszt/resources/refs/heads/main/joodle/1.17.png")!,
                    URL(string: "https://raw.githubusercontent.com/xmliszt/resources/refs/heads/main/joodle/1.16.png")!
                ],
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
