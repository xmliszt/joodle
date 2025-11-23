//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case minimal = "Minimal"
  case excerpt = "Excerpt"
  case detailed = "Detailed"

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
    }
  }

  var description: String {
    switch self {
    case .minimal:
      return "Just your doodle"
    case .excerpt:
      return "Doodle and first few words of your note"
    case .detailed:
      return "Smaller doodle and more words of your note"
    }
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
    }
  }
}
