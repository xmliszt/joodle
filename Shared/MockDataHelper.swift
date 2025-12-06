//
//  MockData.swift
//  Joodle
//
//  Created by Li Yuxuan on 8/11/25.
//
import SwiftUI

func createMockDrawingData() -> Data {
  struct PathData: Codable {
    let points: [CGPoint]
    let isDot: Bool
  }

  // Draw a rectangle around the border of the 300x300 canvas
  let paths = [
    // Border rectangle
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 300, y: 0),
        CGPoint(x: 300, y: 300),
        CGPoint(x: 0, y: 300),
        CGPoint(x: 0, y: 0),
      ], isDot: false),
    // Diagonal line
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 300, y: 300),
      ], isDot: false),
    // Other diagonal
    PathData(
      points: [
        CGPoint(x: 300, y: 0),
        CGPoint(x: 0, y: 300),
      ], isDot: false),
  ]

  return (try? JSONEncoder().encode(paths)) ?? Data()
}
