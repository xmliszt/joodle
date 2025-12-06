//
//  Item.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation
import SwiftData

@Model
final class DayEntry {
  var body: String = ""
  var createdAt: Date = Date()
  var drawingData: Data?

  // Pre-rendered thumbnails for optimized display
  var drawingThumbnail20: Data?  // 20px for year grid view
  var drawingThumbnail200: Data?  // 200px for detail view
  var drawingThumbnail1080: Data?  // 1080px for sharing

  init(body: String, createdAt: Date, drawingData: Data? = nil) {
    self.body = body
    self.createdAt = createdAt
    self.drawingData = drawingData
    self.drawingThumbnail20 = nil
    self.drawingThumbnail200 = nil
    self.drawingThumbnail1080 = nil
  }
}
