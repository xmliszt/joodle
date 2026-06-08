//
//  ShareCardStyle.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case minimal = "Minimal"
  case excerpt = "Excerpt"
  case detailed = "Detailed"
  case anniversary = "Anniversary"
  // Week & Month grid styles
  case weekGrid = "Week Grid"
  case monthGrid = "Month Grid"
  case yearGridDots = "Year Grid"
  case yearGridJoodles = "Year Grid with Joodles"
  case yearGridJoodlesOnly = "Year Grid with Joodles Only"
  // Animated styles
  case animatedMinimalVideo = "Minimal Video"
  case animatedExcerptVideo = "Excerpt Video"
  // Wiggly animated styles — always boil, regardless of the experimental preference
  case animatedWigglyMinimalVideo = "Wiggly Minimal"
  case animatedWigglyExcerptVideo = "Wiggly Excerpt"

  var id: String { rawValue }

  /// Deprecated, do not use
  var icon: String {
    switch self {
    case .minimal, .excerpt, .detailed, .anniversary:
      return "photo.on.rectangle"
    case .weekGrid, .monthGrid, .yearGridDots, .yearGridJoodles, .yearGridJoodlesOnly:
      return "calendar"
    case .animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return "video.fill"
    }
  }

  var displayName: LocalizedStringResource {
    switch self {
    case .minimal:
      return "Minimal"
    case .excerpt:
      return "Excerpt"
    case .detailed:
      return "Detailed"
    case .anniversary:
      return "Anniversary"
    case .weekGrid:
      return "Week Grid"
    case .monthGrid:
      return "Month Grid"
    case .yearGridDots:
      return "Year Grid"
    case .yearGridJoodles:
      return "Year Grid with Joodles"
    case .yearGridJoodlesOnly:
      return "Year Grid with Joodles Only"
    case .animatedMinimalVideo:
      return "Minimal Video"
    case .animatedExcerptVideo:
      return "Excerpt Video"
    case .animatedWigglyMinimalVideo:
      return "Wiggly Minimal"
    case .animatedWigglyExcerptVideo:
      return "Wiggly Excerpt"
    }
  }

  var description: LocalizedStringResource {
    switch self {
    case .minimal:
      return "Doodle only"
    case .excerpt:
      return "Doodle & note snippet"
    case .detailed:
      return "Doodle & more note"
    case .anniversary:
      return "Doodle and countdown"
    case .yearGridDots:
      return "Year progress with dots"
    case .yearGridJoodles:
      return "Year progress with doodles"
    case .yearGridJoodlesOnly:
      return "Year progress with doodles only"
    case .weekGrid:
      return "Your week in doodles"
    case .monthGrid:
      return "Your month in doodles"
    case .animatedMinimalVideo:
      return "Animated doodle"
    case .animatedExcerptVideo:
      return "Animated doodle & note snippet"
    case .animatedWigglyMinimalVideo:
      return "Wiggly doodle"
    case .animatedWigglyExcerptVideo:
      return "Wiggly doodle & note snippet"
    }
  }

  /// Whether this style requires year data instead of single day entry
  var isYearGridStyle: Bool {
    switch self {
    case .yearGridDots, .yearGridJoodles, .yearGridJoodlesOnly:
      return true
    default:
      return false
    }
  }

  /// Whether this style is a week grid style
  var isWeekStyle: Bool {
    self == .weekGrid
  }

  /// Whether this style is a month grid style
  var isMonthStyle: Bool {
    self == .monthGrid
  }

  /// Whether this style is an animated export (GIF or Video)
  var isAnimatedStyle: Bool {
    switch self {
    case .animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Whether this style exports as Video
  var isVideoStyle: Bool {
    switch self {
    case .animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Whether this style always boils the strokes, regardless of the experimental
  /// `enableWigglyStrokes` preference. The dedicated wiggly video styles do; the
  /// plain video styles only wiggle when the preference is on.
  var forcesWiggle: Bool {
    switch self {
    case .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Whether this style includes excerpt text
  var includesExcerpt: Bool {
    switch self {
    case .excerpt, .detailed, .animatedExcerptVideo, .animatedWigglyExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Styles for single day entry sharing (static images)
  static var entryStyles: [ShareCardStyle] {
    [.minimal, .excerpt, .detailed, .anniversary]
  }

  /// Styles for year grid sharing
  static var yearGridStyles: [ShareCardStyle] {
    [.yearGridDots, .yearGridJoodles, .yearGridJoodlesOnly]
  }

  /// Styles for week grid sharing
  static var weekGridStyles: [ShareCardStyle] {
    [.weekGrid]
  }

  /// Styles for month grid sharing
  static var monthGridStyles: [ShareCardStyle] {
    [.monthGrid]
  }

  /// All grid-based styles (week + month + year)
  static var allGridStyles: [ShareCardStyle] {
    weekGridStyles + monthGridStyles + yearGridStyles
  }

  /// Animated styles for entry sharing
  static var animatedStyles: [ShareCardStyle] {
    [.animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo]
  }

  /// All entry styles including animated (static + animated)
  static var allEntryStyles: [ShareCardStyle] {
    entryStyles + animatedStyles
  }

  /// Size for the actual share card, this is the dimension of the image/video saved.
  var cardSize: CGSize {
    switch self {
    case .weekGrid:
      return CGSize(width: 1080, height: 540)
    case .animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return CGSize(width: 1080, height: 1080)
    default:
      return CGSize(width: 1080, height: 1080)
    }
  }

  /// Size for the preview in the carousel, this is the display size on device
  var previewSize: CGSize {
    switch self {
    case .weekGrid:
      return CGSize(width: 300, height: 150)
    default:
      return CGSize(width: 300, height: 300)
    }
  }

  /// Animation configuration for this style
  var animationConfig: DrawingAnimationConfig {
    switch self {
    case .animatedMinimalVideo, .animatedExcerptVideo, .animatedWigglyMinimalVideo, .animatedWigglyExcerptVideo:
      return .video
    default:
      return .default
    }
  }
}
