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
    var onDismiss: (() -> Void)?

    @State private var showCompletionScreen = false
    @State private var hasTriggeredCompletion = false

    var body: some View {
        ZStack {
            // Dimmed background - blocks all touches
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { } // Consume taps to prevent pass-through

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
                    .overlay {
                        if showCompletionScreen {
                            Image(systemName: "checkmark")
                                .font(.appFont(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                // Title
                Text(showCompletionScreen ? "Theme Changed" : "Updating Theme")
                    .font(.appHeadline())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                // Progress info
                VStack(spacing: 16) {
                    if showCompletionScreen {
                        Text("Your new theme is ready!")
                            .font(.appSubheadline())
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    } else if themeColorManager.totalEntriesToProcess > 0 {
                        Text("Regenerating thumbnails...")
                            .font(.appSubheadline())
                            .foregroundStyle(.secondary)

                        // Progress bar
                        ProgressView(value: themeColorManager.regenerationProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                            .tint(.secondary)

                        // Count
                        Text("\(themeColorManager.entriesProcessed, format: .number.grouping(.never)) / \(themeColorManager.totalEntriesToProcess, format: .number.grouping(.never))")
                            .font(.appCaption())
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.secondary)

                        Text("Preparing...")
                            .font(.appSubheadline())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(32)
            .background {
              if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                  .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
              } else {
                // Fallback on earlier versions
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                  .fill(.background)
              }
            }
        }
        .transition(.opacity)
        .onAppear {
            // Reset state for fresh overlay instance
            showCompletionScreen = false
            hasTriggeredCompletion = false
        }
        .onChange(of: themeColorManager.isRegenerating) { _, _ in
            if shouldComplete() {
                triggerCompletion()
            }
        }
        .onChange(of: themeColorManager.regenerationProgress) { _, _ in
            if shouldComplete() {
                triggerCompletion()
            }
        }
        .onChange(of: themeColorManager.totalEntriesToProcess) { _, _ in
            if shouldComplete() {
                triggerCompletion()
            }
        }
        .task {
            // Handle fast-complete paths (e.g. no drawings) where regeneration may
            // start and finish before this overlay observes intermediate states.
            if shouldComplete() {
                triggerCompletion()
                return
            }

            // Poll as a safety net in case rapid state changes are missed by onChange.
            while !hasTriggeredCompletion {
                try? await Task.sleep(for: .milliseconds(100))

                if shouldComplete() {
                    triggerCompletion()
                    break
                }
            }
        }
    }

    private func shouldComplete() -> Bool {
        // Normal completion path
        if !themeColorManager.isRegenerating && themeColorManager.regenerationProgress >= 1.0 {
            return true
        }

        // Fast path: for zero-entry runs, the manager can finish before this
        // overlay observes isRegenerating = true. If the selected color is
        // already applied and manager is idle, treat as complete.
        if !themeColorManager.isRegenerating && UserPreferences.shared.accentColor == selectedColor {
            return true
        }

        return false
    }

    private func triggerCompletion() {
        guard !hasTriggeredCompletion else { return }
        hasTriggeredCompletion = true

        // Show completion screen with animation
        withAnimation(.spring(duration: 0.4)) {
            showCompletionScreen = true
        }

        // Dismiss after 1.5 seconds
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                onDismiss?()
            }
        }
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

#Preview("Completion Screen") {
    ZStack {
        // Mock background
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        ThemeColorLoadingOverlayCompletionPreview()
    }
}

/// Helper view for previewing the completion state
private struct ThemeColorLoadingOverlayCompletionPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            // Color preview
            Circle()
                .fill(ThemeColor.purple.color)
                .frame(width: 60, height: 60)
                .overlay {
                    Circle()
                        .strokeBorder(ThemeColor.purple.color.opacity(0.5), lineWidth: 3)
                        .frame(width: 72, height: 72)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.appFont(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

            Text("Theme Changed")
                .font(.appHeadline())
                .foregroundStyle(.primary)

            Text("Your new theme is ready!")
                .font(.appSubheadline())
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background {
          if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
              .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32))
          } else {
            // Fallback on earlier versions
            RoundedRectangle(cornerRadius: 32, style: .continuous)
              .fill(.background)
          }
        }
    }
}
