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
  case yearGridDots = "Year Grid"
  case yearGridJoodles = "Year Grid with Joodles"
  case yearGridJoodlesOnly = "Year Grid with Joodles Only"
  // Animated styles
  case animatedMinimalGIF = "Minimal GIF"
  case animatedExcerptGIF = "Excerpt GIF"
  case animatedMinimalVideo = "Minimal Video"
  case animatedExcerptVideo = "Excerpt Video"

  var id: String { rawValue }

  /// Deprecated, do not use
  var icon: String {
    switch self {
    case .minimal, .excerpt, .detailed, .anniversary:
      return "photo.on.rectangle"
    case .yearGridDots, .yearGridJoodles, .yearGridJoodlesOnly:
      return "calendar"
    case .animatedMinimalGIF, .animatedExcerptGIF:
      return "photo.on.rectangle.angled"
    case .animatedMinimalVideo, .animatedExcerptVideo:
      return "video.fill"
    }
  }

  var description: String {
    switch self {
    case .minimal:
      return "Joodle only"
    case .excerpt:
      return "Joodle & snippet"
    case .detailed:
      return "Joodle & more text"
    case .anniversary:
      return "Joodle and countdown"
    case .yearGridDots:
      return "Year progress with dots"
    case .yearGridJoodles:
      return "Year progress with Joodles"
    case .yearGridJoodlesOnly:
      return "Year progress with Joodles only"
    case .animatedMinimalGIF:
      return "Animated Joodle as GIF"
    case .animatedExcerptGIF:
      return "Animated Joodle & snippet as GIF"
    case .animatedMinimalVideo:
      return "Animated Joodle as Video"
    case .animatedExcerptVideo:
      return "Animated Joodle & snippet as Video"
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

  /// Whether this style is an animated export (GIF or Video)
  var isAnimatedStyle: Bool {
    switch self {
    case .animatedMinimalGIF, .animatedExcerptGIF, .animatedMinimalVideo, .animatedExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Whether this style exports as GIF
  var isGIFStyle: Bool {
    switch self {
    case .animatedMinimalGIF, .animatedExcerptGIF:
      return true
    default:
      return false
    }
  }

  /// Whether this style exports as Video
  var isVideoStyle: Bool {
    switch self {
    case .animatedMinimalVideo, .animatedExcerptVideo:
      return true
    default:
      return false
    }
  }

  /// Whether this style includes excerpt text
  var includesExcerpt: Bool {
    switch self {
    case .excerpt, .detailed, .animatedExcerptGIF, .animatedExcerptVideo:
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

  /// Animated styles for entry sharing
  static var animatedStyles: [ShareCardStyle] {
    [.animatedMinimalGIF, .animatedExcerptGIF, .animatedMinimalVideo, .animatedExcerptVideo]
  }

  /// All entry styles including animated (static + animated)
  static var allEntryStyles: [ShareCardStyle] {
    entryStyles + animatedStyles
  }

  /// Size for the actual share card, this is the dimension of the image/video saved.
  var cardSize: CGSize {
    switch self {
    // GIF uses smaller size for file size optimization
    case .animatedMinimalGIF, .animatedExcerptGIF:
      return CGSize(width: 540, height: 540)
    // Video uses full size
    case .animatedMinimalVideo, .animatedExcerptVideo:
      return CGSize(width: 1080, height: 1080)
    // Static images use full size
    default:
      return CGSize(width: 1080, height: 1080)
    }
  }

  /// Size for the preview in the carousel, this is the display size on device
  var previewSize: CGSize {
    return CGSize(width: 300, height: 300)
  }

  /// Animation configuration for this style
  var animationConfig: DrawingAnimationConfig {
    switch self {
    case .animatedMinimalGIF, .animatedExcerptGIF:
      return .gif
    case .animatedMinimalVideo, .animatedExcerptVideo:
      return .video
    default:
      return .default
    }
  }
}
