//
//  LocaleProvider.swift
//  Joodle
//

import Foundation

enum LocaleProvider {
  /// Returns the app-resolved locale code used by iOS localization matching.
  /// Respects in-app language override if set by the user.
  /// Example values: "zh-Hans", "en".
  static var currentLanguageCode: String {
    // Check in-app language override first
    let override = UserPreferences.shared.appLanguage
    if !override.isEmpty {
      return override
    }

    if let resolved = Bundle.main.preferredLocalizations.first, !resolved.isEmpty {
      return resolved
    }

    if let fallback = Locale.current.language.languageCode?.identifier, !fallback.isEmpty {
      return fallback
    }

    return "en"
  }
}
