//
//  ThemeColorLoadingOverlay.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// A full-screen overlay that shows progress while regenerating thumbnails for a theme color change
struct ThemeColorLoadingOverlay: View {
    let themeColorManager: ThemeColorManager
    let selectedColor: ThemeColor

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: 24) {
                // Color preview
                Circle()
                    .fill(selectedColor.color)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Circle()
                            .strokeBorder(selectedColor.color.opacity(0.5), lineWidth: 3)
                            .frame(width: 72, height: 72)
                    }

                // Title
                Text("Updating Theme")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Progress info
                VStack(spacing: 8) {
                    if themeColorManager.totalEntriesToProcess > 0 {
                        Text("Regenerating thumbnails...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Progress bar
                        ProgressView(value: themeColorManager.regenerationProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)

                        // Count
                        Text("\(themeColorManager.entriesProcessed) / \(themeColorManager.totalEntriesToProcess)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)

                        Text("Preparing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(32)
            .background {
              RoundedRectangle(cornerRadius: UIDevice.screenCornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview("Loading Overlay") {
    ZStack {
        // Mock background
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        ThemeColorLoadingOverlay(
            themeColorManager: ThemeColorManager.shared,
            selectedColor: .purple
        )
    }
}
