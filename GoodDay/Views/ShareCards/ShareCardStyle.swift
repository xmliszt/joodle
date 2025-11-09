//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case square = "Square"
  case rectangle = "Rectangle"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .square:
      return "square"
    case .rectangle:
      return "rectangle"
    }
  }

  var description: String {
    switch self {
    case .square:
      return "Perfect for Instagram posts"
    case .rectangle:
      return "Great for stories and feeds"
    }
  }

  /// Size for the actual share card (1:1 or 4:5 ratio)
  var cardSize: CGSize {
    switch self {
    case .square:
      return CGSize(width: 1080, height: 1080)
    case .rectangle:
      return CGSize(width: 1080, height: 1350) // 4:5 ratio
    }
  }

  /// Size for the preview in the carousel
  var previewSize: CGSize {
    switch self {
    case .square:
      return CGSize(width: 300, height: 300)
    case .rectangle:
      return CGSize(width: 300, height: 375) // 4:5 ratio
    }
  }
}
