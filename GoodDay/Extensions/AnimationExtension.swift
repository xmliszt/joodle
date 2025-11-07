//
//  Animation.swift
//  GoodDay
//
//  Created by Li Yuxuan on 17/8/25.
//

import SwiftUI

extension Animation {
  public static var springFkingSatifying: Animation {
    // - dampingFraction between 0.6 and 0.8 to feel more lively
    .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.25)
  }
}
