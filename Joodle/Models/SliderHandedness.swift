//
//  SliderHandedness.swift
//  Joodle
//
//  Created by Li Yuxuan on 27/6/26.
//

import Foundation

enum SliderHandedness: String, CaseIterable {
  case left
  case right

  var displayName: LocalizedStringResource {
    switch self {
    case .left: return "Left-handed"
    case .right: return "Right-handed"
    }
  }
}
