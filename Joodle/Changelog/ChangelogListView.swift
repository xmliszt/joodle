//
//  ChangelogListView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// A list view showing all past changelogs, accessible from Settings
struct ChangelogListView: View {
    var body: some View {
        List {
            ForEach(ChangelogData.entries) { entry in
                NavigationLink(destination: ChangelogDetailView(entry: entry)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Version \(entry.displayVersion)")
                                .font(.headline)

                            if entry.version == ChangelogManager.shared.currentAppVersion {
                                Text("Current")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.2))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(entry.date, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangelogListView()
    }
}
