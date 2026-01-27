//
//  ThemeColorPaletteView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftData
import SwiftUI

/// A color palette view that displays available theme colors in a grid layout.
/// Supports individual paywall locks on colors and shows selection state.
struct ThemeColorPaletteView: View {
    @Environment(\.userPreferences) private var userPreferences
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var subscriptionManager: SubscriptionManager

    /// Callback when a locked color is tapped
    var onLockedColorTapped: (() -> Void)?

    /// Callback when color change starts (for showing loading overlay at parent level)
    var onColorChangeStarted: ((ThemeColor) -> Void)?

    /// Callback when color change completes
    var onColorChangeCompleted: (() -> Void)?

    /// Theme color manager for handling thumbnail regeneration
    private var themeColorManager = ThemeColorManager.shared

    /// Size of each color circle
    private let colorCircleSize: CGFloat = 40

    /// Grid columns - 5 colors per row
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    // MARK: - Initializer

    init(
        subscriptionManager: SubscriptionManager,
        onLockedColorTapped: (() -> Void)? = nil,
        onColorChangeStarted: ((ThemeColor) -> Void)? = nil,
        onColorChangeCompleted: (() -> Void)? = nil
    ) {
        self.subscriptionManager = subscriptionManager
        self.onLockedColorTapped = onLockedColorTapped
        self.onColorChangeStarted = onColorChangeStarted
        self.onColorChangeCompleted = onColorChangeCompleted
    }

    /// All available theme colors with their lock state
    private var themeColors: [ThemeColorInfo] {
        ThemeColor.allCases.map { color in
            ThemeColorInfo(themeColor: color, isSubscribed: subscriptionManager.isSubscribed)
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(themeColors) { colorInfo in
                ColorCircleButton(
                    colorInfo: colorInfo,
                    isSelected: userPreferences.accentColor == colorInfo.themeColor,
                    size: colorCircleSize,
                    onTap: {
                        handleColorTap(colorInfo)
                    }
                )
            }
        }
        .padding(.vertical, 16)
    }

    private func handleColorTap(_ colorInfo: ThemeColorInfo) {
        if colorInfo.isLocked {
            onLockedColorTapped?()
        } else {
            // Don't do anything if already selected or already regenerating
            guard userPreferences.accentColor != colorInfo.themeColor,
                  !themeColorManager.isRegenerating else {
                return
            }

            // Track theme color change
            let previousColor = userPreferences.accentColor.rawValue
            AnalyticsManager.shared.trackThemeColorChanged(
                to: colorInfo.themeColor.rawValue,
                from: previousColor
            )

            // Notify parent that color change is starting
            onColorChangeStarted?(colorInfo.themeColor)

            Task {
                await themeColorManager.changeThemeColor(
                    to: colorInfo.themeColor,
                    modelContext: modelContext
                ) {
                    // Notify parent that color change completed
                    onColorChangeCompleted?()
                }
            }
        }
    }
}

// MARK: - Color Circle Button

private struct ColorCircleButton: View {
    let colorInfo: ThemeColorInfo
    let isSelected: Bool
    let size: CGFloat
    let onTap: () -> Void

    /// Whether this is the neutral color which needs half-half representation
    private var isNeutralColor: Bool {
        colorInfo.themeColor == .neutral
    }

    var body: some View {
        Button(action: onTap) {
            Group {
                if isNeutralColor {
                    // Half-half circle for neutral color (black/white)
                    NeutralColorCircle(size: size)
                } else {
                    Circle()
                        .fill(colorInfo.color)
                        .frame(width: size, height: size)
                }
            }
            .overlay {
                // Checkmark for selected state
                if isSelected && !colorInfo.isLocked {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(isNeutralColor ? .gray : .white)
                }
            }
            .overlay {
                // Lock overlay for locked colors
                if colorInfo.isLocked {
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: size, height: size)

                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .circularGlassButton(tintColor: isNeutralColor ? .gray : colorInfo.color)
        .accessibilityLabel("\(colorInfo.displayName) color\(isSelected ? ", selected" : "")\(colorInfo.isLocked ? ", locked" : "")")
        .accessibilityHint(colorInfo.isLocked ? "Requires premium subscription" : "Tap to select this color")
    }
}

// MARK: - Neutral Color Circle (Half Black / Half White)

private struct NeutralColorCircle: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2

            // Left half - dark color
            var leftPath = Path()
            leftPath.move(to: center)
            leftPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: false
            )
            leftPath.closeSubpath()
            context.fill(leftPath, with: .color(.black))

            // Right half - light color
            var rightPath = Path()
            rightPath.move(to: center)
            rightPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: false
            )
            rightPath.closeSubpath()
            context.fill(rightPath, with: .color(.white))

            // Border around the circle
            let borderPath = Path(ellipseIn: CGRect(
                x: 0.5,
                y: 0.5,
                width: canvasSize.width - 1,
                height: canvasSize.height - 1
            ))
            context.stroke(borderPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview("Color Palette - Free User") {
    VStack(alignment: .leading, spacing: 20) {
        Text("Accent Color")
            .font(.headline)

        ThemeColorPaletteView(
            subscriptionManager: SubscriptionManager.shared,
            onLockedColorTapped: {
                print("Locked color tapped!")
            },
            onColorChangeStarted: { color in
                print("Color change started: \(color)")
            },
            onColorChangeCompleted: {
                print("Color change completed")
            }
        )
    }
    .padding()
}

#Preview("Color Palette - In Settings") {
    NavigationStack {
        Form {
            Section("Accent Color") {
                ThemeColorPaletteView(
                    subscriptionManager: SubscriptionManager.shared,
                    onLockedColorTapped: {
                        print("Show paywall")
                    },
                    onColorChangeStarted: { _ in },
                    onColorChangeCompleted: {}
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .navigationTitle("Settings")
    }
}
