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

  // Draw a rectangle around the border of the canvas
  let canvasMax = DOODLE_CANVAS_SIZE
  let paths = [
    // Border rectangle
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: canvasMax, y: 0),
        CGPoint(x: canvasMax, y: canvasMax),
        CGPoint(x: 0, y: canvasMax),
        CGPoint(x: 0, y: 0),
      ], isDot: false),
    // Diagonal line
    PathData(
      points: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: canvasMax, y: canvasMax),
      ], isDot: false),
    // Other diagonal
    PathData(
      points: [
        CGPoint(x: canvasMax, y: 0),
        CGPoint(x: 0, y: canvasMax),
      ], isDot: false),
  ]

  return (try? JSONEncoder().encode(paths)) ?? Data()
}
