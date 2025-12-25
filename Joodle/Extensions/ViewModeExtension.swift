//
//  ViewMode.swift
//  Joodle
//
//  Created by Li Yuxuan on 14/8/25.
//

import Foundation

enum ViewMode {
  case now
  case year
}


extension ViewMode: CaseIterable {
  var rawValue: String {
    switch self {
    case .now: return "now"
    case .year: return "year"
    }
  }

  init?(rawValue: String) {
    switch rawValue {
    case "now": self = .now
    case "year": self = .year
    default: return nil
    }
  }

  var displayName: String {
    switch self {
    case .now: return "Normal"
    case .year: return "Minimized"
    }
  }
}

extension ViewMode {
  var dotSize: CGFloat {
    switch self {
    case .now: return 6.0
    case .year: return 4.0
    }
  }

  var drawingSize: CGFloat {
    switch self {
    case .now: return 48.0
    case .year: return 20.0
    }
  }

  var dotsPerRow: Int {
    switch self {
    case .now: return 7
    case .year: return 16
    }
  }
}
