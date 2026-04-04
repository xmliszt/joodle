# Localization Guide

This document describes how to add a new app locale in Joodle.

## Add a New Locale

1. Add the locale to `AppLanguage` in `Joodle/Models/UserPreferences.swift`.
2. Define three values for the new case:
   - Enum case name (for example, `fr`).
   - `code` (BCP 47 code, for example, `fr` or `pt-BR`).
   - `displayName` (native language name shown in the Settings picker).
3. In Xcode, add the language to project localizations:
   - Project settings -> Info -> Localizations -> `+`.
   - Confirm `Localizable.xcstrings` is included for the new locale.
4. Add translations to both string catalogs:
   - `Localizable.xcstrings` (main app).
   - `Widgets/Localizable.xcstrings` (widgets extension).
5. Ensure remote localized content supports the locale:
   - Changelog endpoint uses `?locale=<code>`.
   - FAQ endpoint uses `?locale=<code>`.
   - Remote alert endpoint uses `?locale=<code>`.
   - Prompt endpoint uses `?locale=<code>`.
6. Run and verify:
   - New locale appears in Settings -> Language.
   - Language switch persists after restart.
   - Main app strings and widget strings are localized.
   - Remote content resolves in the selected locale and falls back to English if missing.

## Notes

- Keep brand names unchanged: `Joodle`, `Joodle Pro`.
- Use locale-aware formatting (dates, plurals, and number formatting).
- Avoid English-specific grammar logic in code paths used for localized UI.
