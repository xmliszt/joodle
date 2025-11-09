//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case square = "Square"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .square:
      return "square"
    }
  }

  var description: String {
    switch self {
    case .square:
      return "Perfect for Instagram posts"
    }
  }

  /// Size for the actual share card (1:1 or 4:5 ratio)
  var cardSize: CGSize {
    switch self {
    case .square:
      return CGSize(width: 1080, height: 1080)
    }
  }

  /// Size for the preview in the carousel
  var previewSize: CGSize {
    switch self {
    case .square:
      return CGSize(width: 300, height: 300)
    }
  }
}
