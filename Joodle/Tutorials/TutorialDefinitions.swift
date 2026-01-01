//
//  TutorialDefinitions.swift
//  Joodle
//

import SwiftUI

/// Defines all available tutorials in the app.
/// Each tutorial contains metadata and content for display in TutorialView.
enum TutorialDefinitions {

  // MARK: - Home Screen Widgets Tutorial

  /// Tutorial for adding Joodle widgets to the home screen
  static let homeScreenWidgets = TutorialData(
    id: "home-screen-widgets",
    title: "Add Home Screen Widgets",
    icon: "square.grid.2x2",
    shortDescription: "Add Joodle to your home screen",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget1.png", dots: [TapDot(x: 122, y: 64)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget2.png", dots: [TapDot(x: 197, y: 147)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget3.png", dots: [TapDot(x: 298, y: 268)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget4.png", dots: [TapDot(x: 240, y: 366)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget5.png"),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget6.png", dots: [TapDot(x: 300, y: 1107)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget7.png", dots: [TapDot(x: 263, y: 496)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Widget8.png")
    ],
    description: "Long press on your home screen, tap the + button, search for \"Joodle\", and add a widget. Some widgets are configurable. Tap the widget while in edit mode to configure.",
    isPremiumFeature: true
  )

  /// Tutorial for adding Joodle widgets to the lock screen
  static let lockScreenWidgets = TutorialData(
    id: "lock-screen-widgets",
    title: "Add Lock Screen Widgets",
    icon: "square.grid.2x2",
    shortDescription: "Add Joodle to your lock screen",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen1.png", dots: [TapDot(x: 306, y: 625)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen2.png", dots: [TapDot(x: 298, y: 1140)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen3.png", dots: [TapDot(x: 298, y: 962)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen4.png"),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen5.png", dots: [TapDot(x: 239, y: 823)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen6.png", dots: [TapDot(x: 299, y: 910)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Lockscreen7.png", dots: [TapDot(x: 478, y: 65)])
    ],
    description: "Long press on your lock screen, tap \"Customize\", then \"ADD WIDGETS\", find \"Joodle\", and tap or drag the widget onto the lock screen.",
    isPremiumFeature: true
  )

  /// Tutorial for adding Joodle widgets to the StandBy screen
  static let standbyWidgets = TutorialData(
    id: "standby-widgets",
    title: "Add StandBy Screen Widgets",
    icon: "square.grid.2x2",
    shortDescription: "Add Joodle to your StandBy screen",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby1.png", dots: [TapDot(x: 802, y: 304)], orientation: .landscape),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby2.png", dots: [TapDot(x: 118, y: 67)], orientation: .landscape),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby3.png", dots: [TapDot(x: 314, y: 306)], orientation: .landscape),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby4.png", dots: [TapDot(x: 823, y: 481)], orientation: .landscape),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby5.png", dots: [TapDot(x: 621, y: 296)], orientation: .landscape),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/Standby6.png", orientation: .landscape)
    ],
    description: "Long press, tap the + button, search for \"Joodle\", and add a widget. Some widgets are configurable. Tap the widget while in edit mode to configure.",
    isPremiumFeature: true
  )

  /// Tutorial for accessing Joodle from Siri Shortcut
  static let siriShortcuts = TutorialData(
    id: "siri-shortcut",
    title: "Quick Access From Siri Shortcuts",
    icon: "magnifyingglass",
    shortDescription: "Quickly jump to today or upcoming anniversary via Siri Shortcuts",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/SiriShortcut1.png", dots: [TapDot(x: 306, y: 758)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/SiriShortcut2.png", dots: [TapDot(x: 237, y: 215)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/SiriShortcut3.png")
    ],
    description: "Open Spotlight Search by swiping down on home screen. Search for \"Joodle\". Tap on any quick action.",
    isPremiumFeature: false
  )

  /// Tutorial for accessing experimental features
  static let experimentalFeatures = TutorialData(
    id: "access-experimental-features",
    title: "Experimental Features",
    icon: "flask",
    shortDescription: "Get early access to experimental features",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/ExperimentalFeature1.png", dots: [TapDot(x: 376, y: 163)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/ExperimentalFeature2.png", dots: [TapDot(x: 352, y: 591)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/ExperimentalFeature3.png", dots: [TapDot(x: 496, y: 726)])
    ],
    description: "In \"Settings\", go to \"Labs\" section, then tap on \"Experimental Features\".",
    isPremiumFeature: true
  )
  
  /// Tutorial for viewing weekday in "Normal" view mode
  static let weekdayLabelView = TutorialData(
    id: "weekday-label-view",
    title: "Quick Peek at Weekday Labels",
    icon: "w.square",
    shortDescription: "Learn how to get a quick peek at the weekday labels in \"Normal\" view mode",
    screenshots: [
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/QuickPeekWeekdayLabel1.png", dots: [TapDot(x: 520, y: 163)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/QuickPeekWeekdayLabel2.png"),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/QuickPeekWeekdayLabel3.png"),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/QuickPeekWeekdayLabel4.png", dots: [TapDot(x: 376, y: 163)]),
      ScreenshotItem(urlString: "https://aikluwlsjdrayohixism.supabase.co/storage/v1/object/public/joodle/Help/QuickPeekWeekdayLabel5.png", dots: [TapDot(x: 408, y: 629)])
    ],
    description: "Swtich to \"Normal\" view mode, then scroll to the top of the grid, continue to scroll and you should see the weekday labels. To change the Start of Week, go to \"Settings\" > \"Start of Week\"."
  )

  // MARK: - All Tutorials

  /// Array of all available tutorials for display in Settings
  static let widgetTutorials: [TutorialData] = [
    homeScreenWidgets,
    lockScreenWidgets,
    standbyWidgets
  ]

  static let otherTutorials: [TutorialData] = [
    siriShortcuts,
    experimentalFeatures,
    weekdayLabelView
  ]
}

// MARK: - Tutorial Data Model

/// Represents a single tutorial with all its content
struct TutorialData: Identifiable {
  let id: String
  let title: String
  let icon: String
  let shortDescription: String
  let screenshots: [ScreenshotItem]
  let description: String?
  let isPremiumFeature: Bool

  init(
    id: String,
    title: String,
    icon: String,
    shortDescription: String,
    screenshots: [ScreenshotItem],
    description: String? = nil,
    isPremiumFeature: Bool = false
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.shortDescription = shortDescription
    self.screenshots = screenshots
    self.description = description
    self.isPremiumFeature = isPremiumFeature
  }
}
