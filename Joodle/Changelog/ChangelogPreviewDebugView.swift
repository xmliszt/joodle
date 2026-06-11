//
//  ChangelogPreviewDebugView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// Debug-only screen that lists every changelog version available from
/// `RemoteChangelogService` and previews the "What's New" bottom sheet for the
/// selected version, presented exactly as it appears on launch.
struct ChangelogPreviewDebugView: View {
    @StateObject private var viewModel = ChangelogViewModel()

    /// The entry whose changelog sheet is currently being previewed.
    @State private var previewEntry: ChangelogEntry?

    /// Version currently being fetched for preview (drives the row spinner).
    @State private var loadingVersion: String?

    var body: some View {
        List {
            if viewModel.isLoadingIndex && viewModel.changelogIndex.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading versions…")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(viewModel.changelogIndex) { entry in
                    Button {
                        previewChangelog(for: entry.version)
                    } label: {
                        versionRow(for: entry)
                    }
                    .disabled(loadingVersion != nil)
                }
            } header: {
                Text("Available Versions")
            } footer: {
                Text("Tap a version to preview its “What's New” bottom sheet, fetched live from RemoteChangelogService.")
            }
        }
        .navigationTitle("Preview Changelog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.clearCacheAndRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingIndex)
            }
        }
        .task {
            await viewModel.fetchChangelogIndex()
        }
        .sheet(item: $previewEntry) { entry in
            NavigationStack {
                ChangelogDetailView(entry: entry)
                    .navigationTitle("What's New")
                    .navigationBarTitleDisplayMode(.large)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func versionRow(for entry: ChangelogIndexEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayVersion)
                    .foregroundStyle(.primary)
                Text(entry.date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loadingVersion == entry.version {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    /// Fetch the full changelog for the version (bypassing caches) and present
    /// it in the bottom sheet once loaded.
    private func previewChangelog(for version: String) {
        loadingVersion = version
        Task {
            let entry = await viewModel.fetchChangelogDetail(for: version, forceRefresh: true)
            loadingVersion = nil
            previewEntry = entry
        }
    }
}
