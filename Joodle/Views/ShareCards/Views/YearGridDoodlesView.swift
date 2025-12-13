//
//  YearGridDoodlesView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI

struct YearGridDoodlesView: View {
  private let cardStyle: ShareCardStyle = .yearGridDoodles
  let year: Int
  let percentage: Double
  let entries: [ShareCardDayEntry]
  var showWatermark: Bool = true

  // Base dimensions for 1080x1080 card
  private let baseDotSize: CGFloat = 26
  private let baseHorizontalPadding: CGFloat = 60
  private let baseTopPadding: CGFloat = 60
  private let baseBottomPadding: CGFloat = 40
  private let baseHeaderSpacing: CGFloat = 32
  private let baseFontSize: CGFloat = 56
  private let baseMinSpacing: CGFloat = 20

  private var dateItems: [ShareCardDateItem] {
    let calendar = Calendar.current
    guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
      return []
    }

    let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365

    return (0..<daysInYear).map { dayOffset in
      let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
      return ShareCardDateItem(
        id: "\(dayOffset)",
        date: date
      )
    }
  }

  private var todayStart: Date {
    Calendar.current.startOfDay(for: Date())
  }

  private var entriesByDateKey: [String: ShareCardDayEntry] {
    var lookup: [String: ShareCardDayEntry] = [:]
    lookup.reserveCapacity(entries.count)
    for entry in entries {
      lookup[entry.dateString] = entry
    }
    return lookup
  }

  private func calculateGridLayout(availableWidth: CGFloat, scale: CGFloat) -> (dotsPerRow: Int, dotSize: CGFloat, spacing: CGFloat) {
    let scaledDotSize = baseDotSize * scale
    let scaledMinSpacing = baseMinSpacing * scale

    // Calculate how many dots can fit in a row
    let dotsPerRow = max(1, Int((availableWidth + scaledMinSpacing) / (scaledDotSize + scaledMinSpacing)))

    // Calculate actual spacing to distribute dots evenly
    let totalDotWidth = CGFloat(dotsPerRow) * scaledDotSize
    let totalSpacing = availableWidth - totalDotWidth
    let spacing = dotsPerRow > 1 ? totalSpacing / CGFloat(dotsPerRow - 1) : 0

    return (dotsPerRow, scaledDotSize, spacing)
  }

  private func numberOfRows(dotsPerRow: Int) -> Int {
    let totalDays = dateItems.count
    return (totalDays + dotsPerRow - 1) / dotsPerRow
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let scale = size.width / cardStyle.cardSize.width

      let horizontalPadding = baseHorizontalPadding * scale
      let topPadding = baseTopPadding * scale
      let bottomPadding = baseBottomPadding * scale
      let headerSpacing = baseHeaderSpacing * scale
      let fontSize = baseFontSize * scale

      let availableWidth = size.width - (horizontalPadding * 2)
      let layout = calculateGridLayout(availableWidth: availableWidth, scale: scale)

      ZStack {
        // Background
        Color.backgroundColor

        VStack(alignment: .leading, spacing: headerSpacing) {
          // Header
          HStack {
            Text(String(year))
              .font(.system(size: fontSize, weight: .semibold))
              .foregroundColor(.primary)

            Spacer()

            Text(String(format: "%.1f%%", percentage))
              .font(.system(size: fontSize, weight: .semibold))
              .foregroundColor(.appPrimary)
          }
          .padding(.horizontal, horizontalPadding)

          // Grid
          VStack(alignment: .leading, spacing: layout.spacing) {
            ForEach(0..<numberOfRows(dotsPerRow: layout.dotsPerRow), id: \.self) { rowIndex in
              createRow(
                for: rowIndex,
                dotsPerRow: layout.dotsPerRow,
                spacing: layout.spacing,
                dotSize: layout.dotSize
              )
            }
          }
          .padding(.horizontal, horizontalPadding)

          Spacer(minLength: 0)
        }
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)

        // Watermark - bottom right corner
        if showWatermark {
          MushroomWatermarkView(scale: scale)
        }
      }
      .frame(width: size.width, height: size.height)
    }
    .aspectRatio(1, contentMode: .fit)
  }

  @ViewBuilder
  private func createRow(for rowIndex: Int, dotsPerRow: Int, spacing: CGFloat, dotSize: CGFloat) -> some View {
    let rowStart = rowIndex * dotsPerRow
    let rowEnd = min(rowStart + dotsPerRow, dateItems.count)

    if rowStart < dateItems.count {
      HStack(spacing: spacing) {
        ForEach(rowStart..<rowEnd, id: \.self) { index in
          let item = dateItems[index]
          let dotStyle = getDotStyle(for: item.date)
          let dayEntry = getEntryForDate(item.date)
          let hasEntry = dayEntry?.hasEntry ?? false

          ShareCardDotView(
            size: dotSize,
            hasEntry: hasEntry,
            dotStyle: dotStyle,
            thumbnail: dayEntry?.thumbnail // Doodles view shows thumbnails
          )
        }

        // Add spacer for the last row if it's not full
        if rowEnd - rowStart < dotsPerRow {
          Spacer(minLength: 0)
        }
      }
    }
  }

  private func getDotStyle(for date: Date) -> ShareCardDotStyle {
    if date < todayStart {
      return .past
    } else if Calendar.current.isDate(date, inSameDayAs: todayStart) {
      return .present
    }
    return .future
  }

  private func getEntryForDate(_ date: Date) -> ShareCardDayEntry? {
    let dateString = DayEntry.dateToString(date)
    return entriesByDateKey[dateString]
  }
}

// MARK: - Preview Helpers

/// Helper function to create mock year entries with doodle thumbnails for previews
/// Uses PLACEHOLDER_DATA to generate realistic doodle thumbnails
func createMockYearEntriesWithDoodles(year: Int, entryCount: Int) -> [ShareCardDayEntry] {
  let calendar = Calendar.current
  guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
    return []
  }

  let daysInYear = calendar.range(of: .day, in: .year, for: startOfYear)?.count ?? 365
  var entries: [ShareCardDayEntry] = []

  // Create entries for random days up to today
  let today = Date()
  var validDays: [Int] = []

  for dayOffset in 0..<daysInYear {
    if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear),
       date <= today {
      validDays.append(dayOffset)
    }
  }

  let daysWithEntries = Set(validDays.shuffled().prefix(min(entryCount, validDays.count)))

  // Generate a thumbnail from PLACEHOLDER_DATA synchronously for preview
  let thumbnailData = generatePreviewThumbnail()

  for dayOffset in daysWithEntries {
    let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
    let dateString = DayEntry.dateToString(date)
    entries.append(ShareCardDayEntry(
      dateString: dateString,
      date: date,
      hasEntry: true,
      thumbnail: thumbnailData
    ))
  }

  return entries
}

/// Generates a small thumbnail image from PLACEHOLDER_DATA for preview purposes
private func generatePreviewThumbnail() -> Data? {
  // Decode the placeholder drawing data
  guard let pathsData = decodePreviewDrawingData(PLACEHOLDER_DATA) else {
    return nil
  }

  let size: CGFloat = 20
  let strokeMultiplier: CGFloat = 2.5 // Thicker strokes for small thumbnails

  // Calculate bounds for scaling
  var minX = CGFloat.infinity, minY = CGFloat.infinity
  var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

  for pathData in pathsData {
    for point in pathData.points {
      minX = min(minX, point.x)
      minY = min(minY, point.y)
      maxX = max(maxX, point.x)
      maxY = max(maxY, point.y)
    }
  }

  guard minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite else {
    return nil
  }

  let drawingWidth = maxX - minX
  let drawingHeight = maxY - minY
  let maxDimension = max(drawingWidth, drawingHeight)

  guard maxDimension > 0 else { return nil }

  let scale = (size * 0.8) / maxDimension // 80% of size for padding
  let offsetX = (size - drawingWidth * scale) / 2 - minX * scale
  let offsetY = (size - drawingHeight * scale) / 2 - minY * scale

  // Render the thumbnail
  let format = UIGraphicsImageRendererFormat()
  format.scale = 1.0
  format.opaque = false

  let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
  let image = renderer.image { context in
    let cgContext = context.cgContext

    // Set drawing properties
    cgContext.setLineCap(.round)
    cgContext.setLineJoin(.round)
    cgContext.setStrokeColor(UIColor(Color.appPrimary).cgColor)
    cgContext.setFillColor(UIColor(Color.appPrimary).cgColor)

    for pathData in pathsData {
      if pathData.isDot, let center = pathData.points.first {
        // Draw dot
        let scaledX = center.x * scale + offsetX
        let scaledY = center.y * scale + offsetY
        let dotRadius = max(1.0, 2.0 * scale * strokeMultiplier)
        cgContext.fillEllipse(in: CGRect(
          x: scaledX - dotRadius,
          y: scaledY - dotRadius,
          width: dotRadius * 2,
          height: dotRadius * 2
        ))
      } else if pathData.points.count >= 2 {
        // Draw path
        cgContext.setLineWidth(max(1.0, 4.0 * scale * strokeMultiplier))
        cgContext.beginPath()

        let firstPoint = pathData.points[0]
        cgContext.move(to: CGPoint(
          x: firstPoint.x * scale + offsetX,
          y: firstPoint.y * scale + offsetY
        ))

        for i in 1..<pathData.points.count {
          let point = pathData.points[i]
          cgContext.addLine(to: CGPoint(
            x: point.x * scale + offsetX,
            y: point.y * scale + offsetY
          ))
        }

        cgContext.strokePath()
      }
    }
  }

  return image.pngData()
}

/// Simple path data structure for preview thumbnail generation
private struct PreviewPathData {
  let points: [CGPoint]
  var isDot: Bool { points.count == 1 }
}

/// Decodes drawing data for preview purposes
private func decodePreviewDrawingData(_ data: Data) -> [PreviewPathData]? {
  guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
    return nil
  }

  var paths: [PreviewPathData] = []

  for pathDict in json {
    guard let pointsArray = pathDict["points"] as? [[Double]] else { continue }

    let points = pointsArray.compactMap { coords -> CGPoint? in
      guard coords.count >= 2 else { return nil }
      return CGPoint(x: coords[0], y: coords[1])
    }

    if !points.isEmpty {
      paths.append(PreviewPathData(points: points))
    }
  }

  return paths.isEmpty ? nil : paths
}

// MARK: - Previews

#Preview("Year Grid Doodles - With Thumbnails") {
  YearGridDoodlesView(
    year: 2025,
    percentage: 45.2,
    entries: createMockYearEntriesWithDoodles(year: 2025, entryCount: 120)
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}

#Preview("Year Grid Doodles - Full Size") {
  YearGridDoodlesView(
    year: 2025,
    percentage: 45.2,
    entries: createMockYearEntriesWithDoodles(year: 2025, entryCount: 120)
  )
  .frame(width: 1080, height: 1080)
}

#Preview("Year Grid Doodles - Empty") {
  YearGridDoodlesView(
    year: 2025,
    percentage: 0.0,
    entries: []
  )
  .frame(width: 300, height: 300)
  .border(Color.gray)
}
