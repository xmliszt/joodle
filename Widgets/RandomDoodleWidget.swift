//
//  RandomJoodleWidget.swift
//  Widgets
//
//  Created by Widget Extension
//

import SwiftUI
import WidgetKit

/// A seedable random number generator for consistent random selection
struct SeededRandomNumberGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    // Use SplitMix64 to properly mix the seed into initial state
    // This ensures even similar seeds (consecutive dates) produce very different states
    self.state = Self.splitMix64(seed)

    // Warm up the generator by discarding first few values
    // This further decorrelates outputs from similar seeds
    for _ in 0..<4 {
      _ = next()
    }
  }

  /// SplitMix64 hash function for seed mixing
  /// Ensures small changes in input produce large changes in output
  private static func splitMix64(_ seed: UInt64) -> UInt64 {
    var z = seed &+ 0x9E3779B97F4A7C15
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
  }

  mutating func next() -> UInt64 {
    // Xorshift64 algorithm
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

struct RandomJoodleProvider: TimelineProvider {
  func placeholder(in context: Context) -> RandomJoodleEntry {
    var (generator, _) = makeSeededGenerator(for: Date(), family: context.family)
    return RandomJoodleEntry(date: Date(), Joodle: nil, prompt: getRandomPrompt(using: &generator), isSubscribed: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (RandomJoodleEntry) -> Void) {
    let currentDate = Date()
    let isSubscribed = WidgetDataManager.shared.isSubscribed()

    // Use a seeded random generator based on the current date and widget family
    var (generator, _) = makeSeededGenerator(for: currentDate, family: context.family)

    let entry = RandomJoodleEntry(
      date: currentDate,
      Joodle: isSubscribed ? getRandomJoodle(using: &generator, family: context.family) : nil,
      prompt: getRandomPrompt(using: &generator),
      isSubscribed: isSubscribed
    )
    completion(entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RandomJoodleEntry>) -> Void)
  {
    let currentDate = Date()
    let isSubscribed = WidgetDataManager.shared.isSubscribed()

    // Use a seeded random generator based on the current date and widget family to ensure
    // consistent random selection for the same day, but different results per widget type
    var (generator, _) = makeSeededGenerator(for: currentDate, family: context.family)
    let Joodle = isSubscribed ? getRandomJoodle(using: &generator, family: context.family) : nil

    let entry = RandomJoodleEntry(
      date: currentDate,
      Joodle: Joodle,
      prompt: getRandomPrompt(using: &generator),
      isSubscribed: isSubscribed
    )

    // Update widget at midnight for the new day
    // Subscription changes are handled by WidgetCenter.reloadAllTimelines() in the main app
    let calendar = Calendar.current
    let nextUpdate = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: currentDate)
    )!

    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
    completion(timeline)
  }

  /// Creates a seeded random number generator based on the date (day granularity) and widget family
  private func makeSeededGenerator(for date: Date, family: WidgetFamily) -> (SeededRandomNumberGenerator, UInt64) {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let dateSeed = UInt64(components.year! * 10000 + components.month! * 100 + components.day!)
    // Use distinct prime multipliers for each family to ensure very different bit patterns
    let familyMultiplier: UInt64 = switch family {
    case .systemSmall: 0x9E3779B97F4A7C15       // Golden ratio based
    case .systemMedium: 0xBF58476D1CE4E5B9      // Splitmix64 constant
    case .systemLarge: 0x94D049BB133111EB       // Splitmix64 constant
    case .systemExtraLarge: 0xC6A4A7935BD1E995  // MurmurHash constant
    case .accessoryCircular: 0x517CC1B727220A95 // Random prime-based
    case .accessoryRectangular: 0x2545F4914F6CDD1D // Weyl sequence
    case .accessoryInline: 0x6A09E667F3BCC909   // SHA-256 fractional
    @unknown default: 0x85EBCA6B
    }
    // XOR the date seed with the family multiplier for maximum bit difference
    let finalSeed = dateSeed ^ familyMultiplier
    return (SeededRandomNumberGenerator(seed: finalSeed), finalSeed)
  }

  /// Returns the index that was selected for the previous day (to avoid repeats)
  private func getPreviousDaySelectedIndex(entriesCount: Int, family: WidgetFamily) -> Int? {
    guard entriesCount > 1 else { return nil }

    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    var (yesterdayGenerator, _) = makeSeededGenerator(for: yesterday, family: family)
    return Int.random(in: 0..<entriesCount, using: &yesterdayGenerator)
  }

  private func getRandomJoodle(using generator: inout SeededRandomNumberGenerator, family: WidgetFamily) -> JoodleData? {
    let entries = WidgetDataManager.shared.loadEntries()

    // Filter entries from the past year (365 days back) that have drawings
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let oneYearAgo = calendar.date(byAdding: .day, value: -365, to: today)!

    // Get today's dateString and one year ago dateString for comparison (timezone-agnostic)
    let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
    let todayString = String(format: "%04d-%02d-%02d", todayComponents.year ?? 0, todayComponents.month ?? 1, todayComponents.day ?? 1)
    let oneYearAgoComponents = calendar.dateComponents([.year, .month, .day], from: oneYearAgo)
    let oneYearAgoString = String(format: "%04d-%02d-%02d", oneYearAgoComponents.year ?? 0, oneYearAgoComponents.month ?? 1, oneYearAgoComponents.day ?? 1)

    // Filter using dateString comparison (timezone-agnostic)
    let JoodleEntries = entries.filter { entry in
      return entry.hasDrawing && entry.drawingData != nil
        && entry.dateString >= oneYearAgoString
        && entry.dateString <= todayString
    }

    guard !JoodleEntries.isEmpty else {
      return nil
    }

    // Select a random Joodle using the seeded generator
    var randomIndex = Int.random(in: 0..<JoodleEntries.count, using: &generator)

    // Ensure we don't pick the same doodle as yesterday (if there's more than one option)
    if JoodleEntries.count > 1,
       let previousIndex = getPreviousDaySelectedIndex(entriesCount: JoodleEntries.count, family: family),
       randomIndex == previousIndex {
      // Pick the next index to avoid repetition
      randomIndex = (randomIndex + 1) % JoodleEntries.count
    }

    let selectedEntry = JoodleEntries[randomIndex]

    return JoodleData(
      dateString: selectedEntry.dateString,
      drawingData: selectedEntry.drawingData!
    )
  }

  private func getRandomPrompt(using generator: inout SeededRandomNumberGenerator) -> String {
    let randomIndex = Int.random(in: 0..<EMPTY_PLACEHOLDERS.count, using: &generator)
    return EMPTY_PLACEHOLDERS[randomIndex]
  }
}

struct RandomJoodleEntry: TimelineEntry {
  let date: Date
  let Joodle: JoodleData?
  let prompt: String
  let isSubscribed: Bool
}

struct JoodleData {
  /// The timezone-agnostic date string in "yyyy-MM-dd" format
  let dateString: String
  let drawingData: Data

  /// Computed display date from dateString (for UI components that need Date)
  var date: Date {
    let components = dateString.split(separator: "-")
    if components.count == 3,
       let year = Int(components[0]),
       let month = Int(components[1]),
       let day = Int(components[2]) {
      var dateComponents = DateComponents()
      dateComponents.year = year
      dateComponents.month = month
      dateComponents.day = day
      return Calendar.current.date(from: dateComponents) ?? Date()
    }
    return Date()
  }
}

struct PathData: Codable {
  let points: [CGPoint]
  let isDot: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    points = try container.decode([CGPoint].self, forKey: .points)
    isDot = try container.decodeIfPresent(Bool.self, forKey: .isDot) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case points
    case isDot
  }
}

struct RandomJoodleWidgetView: View {
  var entry: RandomJoodleProvider.Entry
  @Environment(\.widgetFamily) var family

  /// Theme color loaded from shared preferences
  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    // Check subscription status first
    if !entry.isSubscribed {
      WidgetLockedView(family: family)
        .widgetURL(URL(string: "joodle://paywall"))
        .containerBackground(for: .widget) {
          Color(UIColor.systemBackground)
        }
    } else {
      switch family {
      case .accessoryCircular:
        LockScreenCircularView(Joodle: entry.Joodle, family: family, themeColor: themeColor)
      default:
        if let Joodle = entry.Joodle {
          JoodleView(drawingData: Joodle.drawingData, family: family, themeColor: themeColor)
            .padding(family == .systemLarge ? 48 : 24)
            .widgetURL(URL(string: "joodle://date/\(Joodle.dateString)"))
            .containerBackground(for: .widget) {
              Color(UIColor.systemBackground)
            }
        } else {
          // Show not found status
          NotFoundView(prompt: entry.prompt, family: family)
            .padding(8)
            .widgetURL(URL(string: "joodle://today"))
            .containerBackground(for: .widget) {
              Color(UIColor.systemBackground)
            }
        }
      }
    }
  }
}

// MARK: - Widget Locked View (Premium Required)

struct WidgetLockedView: View {
  let family: WidgetFamily

  private var themeColor: Color {
    WidgetDataManager.shared.loadThemeColor()
  }

  var body: some View {
    VStack(spacing: family == .systemLarge ? 16 : 8) {
      Image(systemName: "crown.fill")
        .font(.system(size: family == .systemLarge ? 40 : 24))
        .foregroundStyle(
          LinearGradient(
            colors: [themeColor.opacity(0.5), themeColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      if family != .accessoryCircular {
        VStack(spacing: 4) {
          Text("Joodle Super")
            .font(family == .systemLarge ? .headline : .caption.bold())
            .foregroundColor(.primary)

          Text("Upgrade to unlock widgets")
            .font(family == .systemLarge ? .subheadline : .caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
      } else {
        VStack (alignment: .center) {
          Text("Unlock")
            .font(.system(size: 8))
            .foregroundColor(.primary)
          Text("Super")
            .font(.system(size: 8))
            .foregroundColor(.primary)
        }
      }
    }
    .padding()
  }
}

struct LockScreenCircularView: View {
  let Joodle: JoodleData?
  let family: WidgetFamily
  let themeColor: Color

  var body: some View {
    if let Joodle = Joodle {
      ZStack {
        JoodleView(drawingData: Joodle.drawingData, family: family, themeColor: themeColor)
          .padding(8)
      }
      .widgetURL(URL(string: "joodle://date/\(Joodle.dateString)"))
      .containerBackground(for: .widget) {
        Color.clear
      }
    } else {
      ZStack {
        Circle()
          .strokeBorder(lineWidth: 2)
          .foregroundStyle(.secondary.opacity(0.3))

        Image(systemName: "scribble")
          .font(.system(size: 24))
          .foregroundStyle(.secondary)
      }
      .widgetURL(URL(string: "joodle://today"))
      .containerBackground(for: .widget) {
        Color.clear
      }
    }
  }
}

struct JoodleView: View {
  let drawingData: Data
  let family: WidgetFamily
  let themeColor: Color

  var body: some View {
    Canvas { context, size in
      // Decode and draw the paths
      let paths = decodePaths(from: drawingData)

      // Calculate scale to fit drawing in widget
      let scale = min(size.width / 300, size.height / 300)
      let offsetX = (size.width - 300 * scale) / 2
      let offsetY = (size.height - 300 * scale) / 2

      for pathData in paths {
        var scaledPath = Path()

        if pathData.isDot && pathData.points.count >= 1 {
          // Draw dot
          let center = pathData.points[0]
          let dotRadius = 2.5 * scale  // DRAWING_LINE_WIDTH / 2 * scale
          scaledPath.addEllipse(
            in: CGRect(
              x: center.x * scale + offsetX - dotRadius,
              y: center.y * scale + offsetY - dotRadius,
              width: dotRadius * 2,
              height: dotRadius * 2
            )
          )
          context.fill(scaledPath, with: .color(themeColor))
        } else {
          // Draw line
          for (index, point) in pathData.points.enumerated() {
            let scaledPoint = CGPoint(
              x: point.x * scale + offsetX,
              y: point.y * scale + offsetY
            )
            if index == 0 {
              scaledPath.move(to: scaledPoint)
            } else {
              scaledPath.addLine(to: scaledPoint)
            }
          }
          context.stroke(
            scaledPath,
            with: .color(themeColor),
            style: StrokeStyle(
              lineWidth: (family == .accessoryCircular ? 10.0 :5.0) * scale,
              lineCap: .round,
              lineJoin: .round
            )
          )
        }
      }
    }
  }

  private func decodePaths(from data: Data) -> [PathData] {
    do {
      return try JSONDecoder().decode([PathData].self, from: data)
    } catch {
      print("Failed to decode drawing data: \(error)")
      return []
    }
  }
}

struct NotFoundView: View {
  let prompt: String
  let family: WidgetFamily

  var body: some View {
    VStack(alignment: .center, spacing: 8) {
      Image(systemName: "scribble")
        .font(.system(size: family == .systemLarge ? 50 : 32))
        .foregroundColor(.secondary.opacity(0.3))
      Text(prompt)
        .font(family == .systemLarge ? .system(size: 16) : .system(size: 12))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}

struct RandomJoodleWidget: Widget {
  let kind: String = "RandomJoodleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RandomJoodleProvider()) { entry in
      RandomJoodleWidgetView(entry: entry)
    }
    .configurationDisplayName("Random Joodle")
    .description("Random Joodle from your collection. Refreshed daily.")
    .supportedFamilies([.systemSmall, .systemLarge, .accessoryCircular])
  }
}

#Preview(as: .systemSmall) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle (subscribed)
  let mockDrawingData = createMockDrawingData()
  let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
  let todayString = String(format: "%04d-%02d-%02d", todayComponents.year ?? 0, todayComponents.month ?? 1, todayComponents.day ?? 1)
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(dateString: todayString, drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}

#Preview(as: .systemLarge) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle from 5 days ago (subscribed)
  let mockDrawingData = createMockDrawingData()
  let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
  let fiveDaysAgoComponents = Calendar.current.dateComponents([.year, .month, .day], from: fiveDaysAgo)
  let fiveDaysAgoString = String(format: "%04d-%02d-%02d", fiveDaysAgoComponents.year ?? 0, fiveDaysAgoComponents.month ?? 1, fiveDaysAgoComponents.day ?? 1)
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(dateString: fiveDaysAgoString, drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}

#Preview(as: .accessoryCircular) {
  RandomJoodleWidget()
} timeline: {
  // Preview with a Joodle (subscribed)
  let mockDrawingData = createMockDrawingData()
  let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
  let todayString = String(format: "%04d-%02d-%02d", todayComponents.year ?? 0, todayComponents.month ?? 1, todayComponents.day ?? 1)
  RandomJoodleEntry(
    date: Date(),
    Joodle: JoodleData(dateString: todayString, drawingData: mockDrawingData),
    prompt: "Draw something",
    isSubscribed: true
  )

  // Preview without subscription (locked)
  RandomJoodleEntry(date: Date(), Joodle: nil, prompt: "Your canvas is lonely 🥺", isSubscribed: false)
}
