//
//  RainbowPalette.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI
import UIKit

/// The 12 per-month colors of the rainbow theme, shared between the app and the
/// widget extension (the widget target does not compile `ThemeColor`). A doodle
/// is painted in its month's color; empty months/chrome fall back elsewhere.
///
/// A continuous hue sweep that reads as a rainbow when the months are seen
/// together, and loosely seasonal: cool winter blues → spring greens → warm
/// summer → autumn reds/pinks → a deep-purple December. Values are Material
/// palette hues, deepened for light mode (~600/700) and lightened for dark mode
/// (~300) so thin strokes stay legible on both backgrounds.
enum RainbowPalette {
    /// Index 0 = January … 11 = December.
    static let colors: [Color] = [
        dynamicColor(light: 0x3949AB, dark: 0x7986CB), // Jan — Indigo
        dynamicColor(light: 0x1E88E5, dark: 0x64B5F6), // Feb — Blue
        dynamicColor(light: 0x00897B, dark: 0x4DB6AC), // Mar — Teal
        dynamicColor(light: 0x43A047, dark: 0x81C784), // Apr — Green
        dynamicColor(light: 0x7CB342, dark: 0xAED581), // May — Light Green
        dynamicColor(light: 0xF9A825, dark: 0xFFD54F), // Jun — Amber
        dynamicColor(light: 0xFB8C00, dark: 0xFFB74D), // Jul — Orange
        dynamicColor(light: 0xF4511E, dark: 0xFF8A65), // Aug — Deep Orange
        dynamicColor(light: 0xE53935, dark: 0xEF5350), // Sep — Red
        dynamicColor(light: 0xD81B60, dark: 0xF06292), // Oct — Pink
        dynamicColor(light: 0x8E24AA, dark: 0xBA68C8), // Nov — Purple
        dynamicColor(light: 0x5E35B1, dark: 0x9575CD)  // Dec — Deep Purple
    ]

    /// The color for a given month (1 = January … 12 = December).
    /// Out-of-range months are clamped so callers can pass raw components safely.
    static func color(forMonth month: Int) -> Color {
        let index = min(max(month, 1), 12) - 1
        return colors[index]
    }

    private static func dynamicColor(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
