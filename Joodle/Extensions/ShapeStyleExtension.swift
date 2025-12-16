//
//  ShapeStyle.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/8/25.
//

import SwiftUI


/// ShapeStyle extension providing consistent dynamic colors across the app
extension ShapeStyle where Self == Color {
  /// The app's accent color based on user's theme preference
  /// Use this instead of `.accent` to respect the user's selected theme color
  static var appAccent: Color {
    UserPreferences.shared.accentColor.color
  }

  /// The contrast color for text/icons displayed on top of appAccent
  /// Use this instead of `.white` when the background is `.appAccent`
  static var appAccentContrast: Color {
    UserPreferences.shared.accentColor.contrastColor
  }

  /// Primary background color that adapts to light/dark mode
  static var backgroundColor: Color {
    Color(UIColor.systemBackground)
  }

  /// Primary text color that adapts to light/dark mode
  static var textColor: Color {
    Color(UIColor.label)
  }

  /// Secondary text color with reduced opacity
  static var secondaryTextColor: Color {
    Color(UIColor.secondaryLabel)
  }

  /// Background color for interactive controls
  static var controlBackgroundColor: Color {
    Color(UIColor.tertiarySystemFill)
  }

  /// Border color for UI elements
  static var borderColor: Color {
    Color(UIColor.separator)
  }
}
