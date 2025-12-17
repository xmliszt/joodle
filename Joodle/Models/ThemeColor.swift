//
//  ThemeColor.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

/// Represents the available theme accent colors in the app.
/// Each case corresponds to a color set in Assets.xcassets/Themes.
enum ThemeColor: String, CaseIterable, Codable, Identifiable {
    case orange = "Orange"
    case blue = "Blue"
    case brown = "Brown"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"
    case red = "Red"
    case teal = "Teal"
    case yellow = "Yellow"
    case neutral = "Neutral"

    var id: String { rawValue }

    /// The display name shown to users
    var displayName: String {
        rawValue
    }

    /// The Color from the asset catalog
    var color: Color {
        Color("Themes/\(rawValue)")
    }

    /// The contrast color for text/icons displayed on top of this accent color
    /// Returns a color that provides good readability when used as foreground on accent background
    var contrastColor: Color {
        switch self {
        case .neutral:
            // Neutral is dark in light mode (needs white text) and light in dark mode (needs dark text)
            // Use the primary label color which is black in light mode and white in dark mode,
            // but we need the opposite, so use the background color
            return Color(UIColor.systemBackground)
        default:
            // All other accent colors are vibrant and work well with white text
            return .white
        }
    }

    /// SF Symbol name for the color (used for accessibility)
    var symbolName: String {
        "circle.fill"
    }

    /// Whether this color requires a premium subscription
    /// Override individual colors here to make them premium
    var isPremium: Bool {
        switch self {
        case .orange:
            // Default color, always free
            return false
        case .blue, .brown, .green, .pink, .purple, .red, .teal, .yellow:
            // All other colors are free for now
            // Change to `true` to paywall individual colors
            return false
        case .neutral:
            return true
        }
    }

    /// The default theme color used when no preference is set
    static let defaultColor: ThemeColor = .orange
}

// MARK: - ThemeColorInfo

/// A wrapper that provides lock state information for a theme color
/// This allows individual colors to be paywalled independently
struct ThemeColorInfo: Identifiable {
    let themeColor: ThemeColor
    let isLocked: Bool

    var id: String { themeColor.id }

    var color: Color { themeColor.color }
    var displayName: String { themeColor.displayName }
    var isPremium: Bool { themeColor.isPremium }

    init(themeColor: ThemeColor, isSubscribed: Bool) {
        self.themeColor = themeColor
        // A color is locked if it's premium AND user is not subscribed
        self.isLocked = themeColor.isPremium && !isSubscribed
    }
}
