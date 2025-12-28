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
      ScreenshotItem(image: Image("Help/Widget1"), dots: [TapDot(x: 122, y: 64)]),
      ScreenshotItem(image: Image("Help/Widget2"), dots: [TapDot(x: 197, y: 147)]),
      ScreenshotItem(image: Image("Help/Widget3"), dots: [TapDot(x: 298, y: 268)]),
      ScreenshotItem(image: Image("Help/Widget4"), dots: [TapDot(x: 240, y: 366)]),
      ScreenshotItem(image: Image("Help/Widget5")),
      ScreenshotItem(image: Image("Help/Widget6"), dots: [TapDot(x: 300, y: 1107)]),
      ScreenshotItem(image: Image("Help/Widget7"), dots: [TapDot(x: 263, y: 496)]),
      ScreenshotItem(image: Image("Help/Widget8"))
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
      ScreenshotItem(image: Image("Help/Lockscreen1"), dots: [TapDot(x: 306, y: 625)]),
      ScreenshotItem(image: Image("Help/Lockscreen2"), dots: [TapDot(x: 298, y: 1140)]),
      ScreenshotItem(image: Image("Help/Lockscreen3"), dots: [TapDot(x: 298, y: 962)]),
      ScreenshotItem(image: Image("Help/Lockscreen4")),
      ScreenshotItem(image: Image("Help/Lockscreen5"), dots: [TapDot(x: 239, y: 823)]),
      ScreenshotItem(image: Image("Help/Lockscreen6"), dots: [TapDot(x: 299, y: 910)]),
      ScreenshotItem(image: Image("Help/Lockscreen7"), dots: [TapDot(x: 478, y: 65)])
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
      ScreenshotItem(image: Image("Help/Standby1"), dots: [TapDot(x: 802, y: 304)], orientation: .landscape),
      ScreenshotItem(image: Image("Help/Standby2"), dots: [TapDot(x: 118, y: 67)], orientation: .landscape),
      ScreenshotItem(image: Image("Help/Standby3"), dots: [TapDot(x: 314, y: 306)], orientation: .landscape),
      ScreenshotItem(image: Image("Help/Standby4"), dots: [TapDot(x: 823, y: 481)], orientation: .landscape),
      ScreenshotItem(image: Image("Help/Standby5"), dots: [TapDot(x: 621, y: 296)], orientation: .landscape),
      ScreenshotItem(image: Image("Help/Standby6"), orientation: .landscape)
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
      ScreenshotItem(image: Image("Help/SiriShortcut1"), dots: [TapDot(x: 306, y: 758)]),
      ScreenshotItem(image: Image("Help/SiriShortcut2"), dots: [TapDot(x: 237, y: 215)]),
      ScreenshotItem(image: Image("Help/SiriShortcut3"))
    ],
    description: "Open Spotlight Search by swiping down on home screen. Search for \"Joodle\". Tap on any quick action.",
    isPremiumFeature: true
  )
  
  /// Tutorial for accessing experimental features
  static let experimentalFeatures = TutorialData(
    id: "access-experimental-features",
    title: "Early Access to Experimental Features",
    icon: "flask",
    shortDescription: "Get early access to experimental features",
    screenshots: [
      ScreenshotItem(image: Image("Help/SiriShortcut1"), dots: [TapDot(x: 306, y: 758)]),
      ScreenshotItem(image: Image("Help/SiriShortcut2"), dots: [TapDot(x: 237, y: 215)]),
      ScreenshotItem(image: Image("Help/SiriShortcut3"))
    ],
    description: "In \"Settings\", go to \"Lab\" section, then tap on \"Experimental Features\".",
    isPremiumFeature: true
  )

  // MARK: - All Tutorials

  /// Array of all available tutorials for display in Settings
  static let widgetTutorials: [TutorialData] = [
    homeScreenWidgets,
    lockScreenWidgets,
    standbyWidgets
  ]
  
  static let siriShortcutTutorial: TutorialData = siriShortcuts
  static let experimentalFeaturesTutotrial: TutorialData = experimentalFeatures
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
