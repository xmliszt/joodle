//
//  TutorialView.swift
//  Joodle
//

import SwiftUI

/// A reusable tutorial view that displays screenshots with optional pulsing dot overlays.
/// Layout: Title (navigation) → Screenshot Carousel → Description (optional)
///
/// Usage:
/// ```
/// NavigationLink {
///     TutorialView(
///         title: "Home Screen Widgets",
///         screenshots: [
///             ScreenshotItem(image: Image("Help/Widget1"), dot: TapDot(x: 300, y: 250))
///         ],
///         description: "Learn how to add widgets to your home screen"
///     )
/// } label: {
///     Text("Home Screen Widgets")
/// }
/// ```
struct TutorialView: View {
    let title: String
    let screenshots: [ScreenshotItem]
    var description: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Screenshot carousel - takes available space
            ScreenshotCarouselView(screenshots: screenshots)
                .padding(.top, 16)

            // Description below screenshots (if provided)
            if let description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dot Position Tweaker

/// Interactive view for tweaking dot positions on screenshots.
/// Tap anywhere on the screenshot to see coordinates for TapDot placement.
/// Supports both portrait and landscape device orientations with adaptive layout.
struct DotPositionTweakerView: View {
    let screenshots: [ScreenshotItem]
    @State private var currentIndex = 0
    @State private var tappedPositions: [TapDot] = []
    @State private var lastTapCoordinate: String = "Tap on screenshot"
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        Group {
            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .navigationTitle("Dot Position Tweaker")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 16) {
            coordinateDisplay
            screenshotView
            if screenshots.count > 1 {
                screenshotSelector
            }
            Spacer()
        }
    }

    // MARK: - Landscape Layout

    private var landscapeLayout: some View {
        HStack(spacing: 16) {
            // Left side: Screenshot
            screenshotView
                .padding(.leading, 16)

            // Right side: Controls
            VStack(spacing: 12) {
                Spacer()
                coordinateDisplayCompact
                if screenshots.count > 1 {
                    screenshotSelectorCompact
                }
                Spacer()
            }
            .frame(minWidth: 180, maxWidth: 220)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Coordinate Display

    private var coordinateDisplay: some View {
        VStack(spacing: 8) {
            Text(lastTapCoordinate)
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.appAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if !tappedPositions.isEmpty {
                Text("All taps: \(tappedPositions.map { "(\(Int($0.x)), \(Int($0.y)))" }.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Clear Taps") {
                tappedPositions.removeAll()
                lastTapCoordinate = "Tap on screenshot"
            }
            .font(.caption)
            .disabled(tappedPositions.isEmpty)
        }
    }

    private var coordinateDisplayCompact: some View {
        VStack(spacing: 6) {
            Text(lastTapCoordinate)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.appAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if !tappedPositions.isEmpty {
                ScrollView {
                    Text(tappedPositions.map { "(\(Int($0.x)), \(Int($0.y)))" }.joined(separator: "\n"))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: 60)
            }

            Button("Clear Taps") {
                tappedPositions.removeAll()
                lastTapCoordinate = "Tap on screenshot"
            }
            .font(.caption2)
            .disabled(tappedPositions.isEmpty)
        }
    }

    // MARK: - Screenshot View

    private var screenshotView: some View {
        Group {
            if screenshots.indices.contains(currentIndex) {
                let item = screenshots[currentIndex]
                GeometryReader { geometry in
                    ZStack {
                        item.image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()

                        // Show existing dots from screenshot definition
                        ForEach(item.dots) { dot in
                            PulsingDotView()
                                .position(
                                    x: (dot.x / item.orientation.originalWidth) * geometry.size.width,
                                    y: (dot.y / item.orientation.originalHeight) * geometry.size.height
                                )
                        }

                        // Show tapped positions as static dots
                        ForEach(tappedPositions) { dot in
                            Circle()
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .position(
                                    x: (dot.x / item.orientation.originalWidth) * geometry.size.width,
                                    y: (dot.y / item.orientation.originalHeight) * geometry.size.height
                                )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        // Convert tap location to original screenshot coordinates
                        let originalX = (location.x / geometry.size.width) * item.orientation.originalWidth
                        let originalY = (location.y / geometry.size.height) * item.orientation.originalHeight

                        let newDot = TapDot(x: originalX, y: originalY)
                        tappedPositions.append(newDot)
                        lastTapCoordinate = "TapDot(x: \(Int(originalX)), y: \(Int(originalY)))"
                    }
                }
                .aspectRatio(item.orientation.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, isLandscape ? 0 : 24)
            }
        }
    }

    // MARK: - Screenshot Selector

    private var screenshotSelector: some View {
        HStack(spacing: 12) {
            ForEach(0..<screenshots.count, id: \.self) { index in
                Button {
                    currentIndex = index
                    tappedPositions.removeAll()
                    lastTapCoordinate = "Tap on screenshot"
                } label: {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(index == currentIndex ? Color.appAccent : Color.secondary.opacity(0.2))
                        .foregroundColor(index == currentIndex ? .appAccentContrast : .primary)
                        .clipShape(Circle())
                }
            }
        }
    }

    private var screenshotSelectorCompact: some View {
        // Use a grid layout for landscape to handle many screenshots
        let columns = [
            GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 6)
        ]

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<screenshots.count, id: \.self) { index in
                Button {
                    currentIndex = index
                    tappedPositions.removeAll()
                    lastTapCoordinate = "Tap on screenshot"
                } label: {
                    Text("\(index + 1)")
                        .font(.caption2.bold())
                        .frame(width: 28, height: 28)
                        .background(index == currentIndex ? Color.appAccent : Color.secondary.opacity(0.2))
                        .foregroundColor(index == currentIndex ? .appAccentContrast : .primary)
                        .clipShape(Circle())
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Basic Tutorial") {
    NavigationStack {
        TutorialView(
            title: "Home Screen Widgets",
            screenshots: [
                ScreenshotItem(
                    image: Image("Help/Widget1")
                )
            ],
            description: "Learn how to add Joodle widgets to your home screen"
        )
    }
}

#Preview("Tutorial with Multiple Screenshots") {
    NavigationStack {
        TutorialView(
            title: "Home Screen Widgets",
            screenshots: [
                ScreenshotItem(image: Image("Help/Widget1")),
                ScreenshotItem(image: Image("Help/Widget2")),
                ScreenshotItem(image: Image("Help/Widget3"))
            ],
            description: "Follow these steps to add widgets"
        )
    }
}

#Preview("Tutorial without Description") {
    NavigationStack {
        TutorialView(
            title: "Quick Guide",
            screenshots: [
                ScreenshotItem(image: Image("Help/Widget1"))
            ]
        )
    }
}

#Preview("In Settings Navigation") {
    NavigationStack {
        List {
            Section("Tutorials") {
                NavigationLink {
                    TutorialView(
                        title: "Home Screen Widgets",
                        screenshots: [
                            ScreenshotItem(image: Image("Help/Widget1")),
                            ScreenshotItem(image: Image("Help/Widget2"))
                        ],
                        description: "Add Joodle to your home screen"
                    )
                } label: {
                    Label("Home Screen Widgets", systemImage: "square.grid.2x2")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Dot Position Tweaker Previews

#Preview("🎯 Dot Tweaker - Widget Screenshots") {
    NavigationStack {
        DotPositionTweakerView(screenshots: [
          ScreenshotItem(image: Image("Help/SiriShortcut1"), dots: [TapDot(x: 306, y: 758)]),
          ScreenshotItem(image: Image("Help/SiriShortcut2"), dots: [TapDot(x: 237, y: 215)]),
          ScreenshotItem(image: Image("Help/SiriShortcut3"))
        ])
    }
}

#Preview("🎯 Dot Tweaker - Single Screenshot") {
    NavigationStack {
        DotPositionTweakerView(screenshots: [
            ScreenshotItem(image: Image("Help/Widget1"))
        ])
    }
}

#Preview("🎯 Dot Tweaker - With Existing Dots") {
    NavigationStack {
        DotPositionTweakerView(screenshots: [
            ScreenshotItem(
                image: Image("Help/Widget1"),
                dots: [
                    TapDot(x: 300, y: 1100)
                ]
            )
        ])
    }
}

#Preview("🎯 Dot Tweaker - Landscape Screenshot") {
    NavigationStack {
        DotPositionTweakerView(screenshots: [
            ScreenshotItem(
                image: Image("Onboarding/WidgetsStandby1"),
                orientation: .landscape
            )
        ])
    }
}

#Preview("🎯 Dot Tweaker - Mixed Orientations") {
    NavigationStack {
        DotPositionTweakerView(screenshots: [
            ScreenshotItem(image: Image("Help/Widget1")),
            ScreenshotItem(
                image: Image("Onboarding/WidgetsStandby1"),
                orientation: .landscape
            ),
            ScreenshotItem(image: Image("Help/Widget2"))
        ])
    }
}
