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
    // Ordered so the palette grid transitions smoothly around the color wheel,
    // starting at the default (orange) and looping back through red → brown.
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case teal = "Teal"
    case blue = "Blue"
    case indigo = "Indigo"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case brown = "Brown"
    case neutral = "Neutral"
    case rainbow = "Rainbow"

    var id: String { rawValue }

    /// The display name shown to users
    var displayName: String {
        switch self {
        case .orange:
            return String(localized: "Orange")
        case .blue:
            return String(localized: "Blue")
        case .indigo:
            return String(localized: "Indigo")
        case .brown:
            return String(localized: "Brown")
        case .green:
            return String(localized: "Green")
        case .pink:
            return String(localized: "Pink")
        case .purple:
            return String(localized: "Purple")
        case .red:
            return String(localized: "Red")
        case .teal:
            return String(localized: "Teal")
        case .yellow:
            return String(localized: "Yellow")
        case .neutral:
            return String(localized: "Neutral")
        case .rainbow:
            return String(localized: "Rainbow")
        }
    }

    /// The Color from the asset catalog.
    /// Rainbow has no single asset color: it is a per-month palette applied only
    /// to doodle strokes (via `drawingColor(forMonth:)`). General UI chrome that
    /// reads `.appAccent` deliberately falls back to the default accent so the
    /// app's buttons/tints stay stable rather than shifting color each month.
    var color: Color {
        if self == .rainbow {
            return Color("Themes/\(ThemeColor.defaultColor.rawValue)")
        }
        return Color("Themes/\(rawValue)")
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
        case .rainbow:
            // Every month color is a saturated mid-tone; white reads on all of them.
            return .white
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
        case .blue, .brown, .green, .indigo, .pink, .purple, .red, .teal, .yellow:
            // All other colors are free for now
            // Change to `true` to paywall individual colors
            return false
        case .neutral:
            return true
        case .rainbow:
            return true
        }
    }

    /// The default theme color used when no preference is set
    static let defaultColor: ThemeColor = .orange

    // MARK: - Rainbow (per-month) palette

    /// Whether this theme paints each month in its own color.
    var isRainbow: Bool { self == .rainbow }

    /// The 12 month colors (index 0 = January … 11 = December). Defined in the
    /// shared `RainbowPalette` so the widget target (which doesn't compile
    /// `ThemeColor`) uses the same values.
    static var rainbowPalette: [Color] { RainbowPalette.colors }

    /// The rainbow color for a given month (1 = January … 12 = December).
    static func rainbowColor(forMonth month: Int) -> Color {
        RainbowPalette.color(forMonth: month)
    }

    /// Resolves the stroke color for a doodle in `month` (1-12): the month's
    /// rainbow color when this theme is rainbow, otherwise the single accent color.
    func drawingColor(forMonth month: Int) -> Color {
        isRainbow ? ThemeColor.rainbowColor(forMonth: month) : color
    }
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

    init(themeColor: ThemeColor, hasPremiumAccess: Bool) {
        self.themeColor = themeColor
        // A color is locked if it's premium AND user is not subscribed
        self.isLocked = themeColor.isPremium && !hasPremiumAccess
    }
}
