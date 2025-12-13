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
  case yearGridJoodles = "Year Joodles"

  var id: String { rawValue }

  /// Deprecated, do not use
  var icon: String {
    switch self {
    case .minimal:
      return "square"
    case .excerpt:
      return "square"
    case .detailed:
      return "square"
    case .anniversary:
      return "square"
    case .yearGridDots:
      return "square.grid.3x3"
    case .yearGridJoodles:
      return "square.grid.3x3.fill"
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
    }
  }

  /// Whether this style requires year data instead of single day entry
  var isYearGridStyle: Bool {
    switch self {
    case .yearGridDots, .yearGridJoodles:
      return true
    default:
      return false
    }
  }

  /// Styles for single day entry sharing
  static var entryStyles: [ShareCardStyle] {
    [.minimal, .excerpt, .detailed, .anniversary]
  }

  /// Styles for year grid sharing
  static var yearGridStyles: [ShareCardStyle] {
    [.yearGridDots, .yearGridJoodles]
  }

  /// Size for the actual share card, this is the dimension of the image saved.
  var cardSize: CGSize {
    switch self {
    case .minimal:
      return CGSize(width: 1080, height: 1080)
    case .excerpt:
      return CGSize(width: 1080, height: 1080)
    case .detailed:
      return CGSize(width: 1080, height: 1080)
    case .anniversary:
      return CGSize(width: 1080, height: 1080)
    case .yearGridDots:
      return CGSize(width: 1080, height: 1080)
    case .yearGridJoodles:
      return CGSize(width: 1080, height: 1080)
    }
  }

  /// Size for the preview in the carousel, this is the display size on device
  var previewSize: CGSize {
    switch self {
    case .minimal:
      return CGSize(width: 300, height: 300)
    case .excerpt:
      return CGSize(width: 300, height: 300)
    case .detailed:
      return CGSize(width: 300, height: 300)
    case .anniversary:
      return CGSize(width: 300, height: 300)
    case .yearGridDots:
      return CGSize(width: 300, height: 300)
    case .yearGridJoodles:
      return CGSize(width: 300, height: 300)
    }
  }
}
