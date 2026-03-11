//
//  LocaleProvider.swift
//  Joodle
//

import Foundation

enum LocaleProvider {
  /// Returns the app-resolved locale code used by iOS localization matching.
  /// Example values: "zh-Hans", "en".
  static var currentLanguageCode: String {
    if let resolved = Bundle.main.preferredLocalizations.first, !resolved.isEmpty {
      return resolved
    }

    if let fallback = Locale.current.language.languageCode?.identifier, !fallback.isEmpty {
      return fallback
    }

    return "en"
  }
}
