//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case doodleOnlySquare = "Square"
  case square2 = "Square2"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .doodleOnlySquare:
      return "square"
    case .square2:
      return "square"
    }
  }

  var description: String {
    switch self {
    case .doodleOnlySquare:
      return ""
    case .square2:
      return "Perfect for Instagram posts, but smaller"
    }
  }

  /// Size for the actual share card (1:1 or 4:5 ratio)
  var cardSize: CGSize {
    switch self {
    case .doodleOnlySquare:
      return CGSize(width: 1080, height: 1080)
    case .square2:
      return CGSize(width: 800, height: 800)
    }
  }

  /// Size for the preview in the carousel
  var previewSize: CGSize {
    switch self {
    case .doodleOnlySquare:
      return CGSize(width: 300, height: 300)
    case .square2:
      return CGSize(width: 200, height: 200)
    }
  }
}
