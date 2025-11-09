//
//  ShareCardStyle.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

enum ShareCardStyle: String, CaseIterable, Identifiable {
  case minimal = "Minimal"
  case classic = "Classic"
  case vibrant = "Vibrant"
  case elegant = "Elegant"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .minimal:
      return "circle"
    case .classic:
      return "square"
    case .vibrant:
      return "star.fill"
    case .elegant:
      return "sparkles"
    }
  }

  var description: String {
    switch self {
    case .minimal:
      return "Clean and simple"
    case .classic:
      return "Traditional style"
    case .vibrant:
      return "Bold and colorful"
    case .elegant:
      return "Refined design"
    }
  }
}
