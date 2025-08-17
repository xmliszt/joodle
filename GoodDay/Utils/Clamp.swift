//
//  Clamp.swift
//  GoodDay
//
//  Created by Li Yuxuan on 16/8/25.
//

import Foundation

func clamp(value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    return max(min(value, maxValue), minValue)
}
