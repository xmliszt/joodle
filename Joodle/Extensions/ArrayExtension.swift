//
//  ArrayExtension.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import Foundation

extension Array {
  /// Safe subscript access that returns nil instead of crashing when index is out of bounds
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}

extension Array where Element == Array<String?> {
  /// Safe 2D array access for our hit testing grid
  subscript(safe row: Int, safe col: Int) -> String? {
    guard let rowData = self[safe: row] else { return nil }
    return rowData[safe: col] ?? nil
  }
}
