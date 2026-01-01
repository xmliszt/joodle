//
//  ChangelogListView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// A list view showing all past changelogs, accessible from Settings
struct ChangelogListView: View {
    @StateObject private var viewModel = ChangelogViewModel()

    var body: some View {
        Group {
            if viewModel.isLoadingIndex && viewModel.changelogIndex.isEmpty {
                // Initial loading state
                ProgressView("Loading changelogs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.changelogIndex.isEmpty {
                // Empty state
                ContentUnavailableView(
                    "No Changelogs",
                    systemImage: "doc.text",
                    description: Text("Check back later for updates.")
                )
            } else {
                // Changelog list
                List {
                    ForEach(viewModel.changelogIndex) { indexEntry in
                        NavigationLink {
                            ChangelogDetailLoadingView(
                                indexEntry: indexEntry,
                                viewModel: viewModel
                            )
                            .navigationTitle("Version \(indexEntry.version)")
                            .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            ChangelogRowView(
                                indexEntry: indexEntry,
                                isCurrentVersion: indexEntry.version == AppEnvironment.fullVersionString
                            )
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchChangelogIndex()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                Task {
                    await viewModel.fetchChangelogIndex(forceRefresh: true)
                }
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
}

// MARK: - Changelog Row View

private struct ChangelogRowView: View {
    let indexEntry: ChangelogIndexEntry
    let isCurrentVersion: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(indexEntry.version)")
                    .font(.headline)

                if let date = indexEntry.parsedDate {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Spacer()

            // Show "Current" badge if this is the running app version
            if isCurrentVersion {
                Text("Current")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.appAccent.opacity(0.2))
                    .foregroundStyle(.appAccent)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Changelog Detail Loading View

/// Wrapper view that handles loading the full changelog detail
private struct ChangelogDetailLoadingView: View {
    let indexEntry: ChangelogIndexEntry
    @ObservedObject var viewModel: ChangelogViewModel

    @State private var entry: ChangelogEntry?
    @State private var isLoading = true
    @State private var loadError: Error?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let entry = entry {
                ChangelogDetailView(entry: entry)
            } else if loadError != nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Could not load changelog content.")
                )
            } else {
                ContentUnavailableView(
                    "Not Found",
                    systemImage: "doc.text",
                    description: Text("Changelog content is unavailable.")
                )
            }
        }
        .task {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        isLoading = true
        loadError = nil

        // First check if we already have the full entry cached
        if let cached = viewModel.loadedEntries[indexEntry.version] {
            entry = cached
            isLoading = false
            return
        }

        // Fetch from remote
        do {
            entry = await viewModel.fetchChangelogDetail(for: indexEntry.version)
        } catch {
            loadError = error
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ChangelogListView()
    }
}
