//
//  ChangelogListView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// A list view showing all past changelogs, accessible from Settings
struct ChangelogListView: View {
  private let entries: [ChangelogEntry] = ChangelogData.entries
  
  var body: some View {
    List {
      ForEach(entries) { entry in
        NavigationLink(destination: ChangelogDetailView(entry: entry)) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Version \(entry.displayVersion)")
                .font(.headline)
              
              
              Text(entry.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            // Show "Current" badge if this is the running app version
            if entry.version == AppEnvironment.rawVersionString {
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
