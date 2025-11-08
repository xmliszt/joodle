//
//  FontExtension.swift
//  GoodDay
//
//  Created by Font Extension
//

import SwiftUI

extension Font {
  // Custom font name
  private static let customFontName = "Mansalva"

  // Custom font with specific size
  static func custom(size: CGFloat) -> Font {
    return .custom(customFontName, size: size)
  }

  // Predefined sizes matching system font styles
  static var customLargeTitle: Font {
    return .custom(customFontName, size: 34)
  }

  static var customTitle: Font {
    return .custom(customFontName, size: 28)
  }

  static var customTitle2: Font {
    return .custom(customFontName, size: 22)
  }

  static var customTitle3: Font {
    return .custom(customFontName, size: 20)
  }

  static var customHeadline: Font {
    return .custom(customFontName, size: 17)
  }

  static var customBody: Font {
    return .custom(customFontName, size: 17)
  }

  static var customCallout: Font {
    return .custom(customFontName, size: 16)
  }

  static var customSubheadline: Font {
    return .custom(customFontName, size: 15)
  }

  static var customFootnote: Font {
    return .custom(customFontName, size: 13)
  }

  static var customCaption: Font {
    return .custom(customFontName, size: 12)
  }

  static var customCaption2: Font {
    return .custom(customFontName, size: 11)
  }
}
