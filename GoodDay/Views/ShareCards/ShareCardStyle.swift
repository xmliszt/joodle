//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case minimalSquare = "Minimal - Square"
  case minimalRectangle = "Minimal - Rectangle"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .minimalSquare:
      return "square"
    case .minimalRectangle:
      return "rectangle"
    }
  }

  var description: String {
    switch self {
    case .minimalSquare:
      return "Perfect for Instagram posts"
    case .minimalRectangle:
      return "With more details..."
    }
  }

  /// Size for the actual share card, this is the dimension of the image saved.
  var cardSize: CGSize {
    switch self {
    case .minimalSquare:
      return CGSize(width: 1080, height: 1080)
    case .minimalRectangle:
      return CGSize(width: 1080, height: 540)
    }
  }

  /// Size for the preview in the carousel, this is the display size on device
  var previewSize: CGSize {
    switch self {
    case .minimalSquare:
      return CGSize(width: 300, height: 300)
    case .minimalRectangle:
      return CGSize(width: 300, height: 150)
    }
  }
}
