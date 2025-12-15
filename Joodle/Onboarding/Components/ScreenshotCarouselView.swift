//
//  ScreenshotCarouselView.swift
//  Joodle
//

import SwiftUI

// MARK: - Models

/// Orientation of the screenshot for aspect ratio calculation
enum ScreenshotOrientation {
    case portrait   // 600 × 1238
    case landscape  // 1238 × 600 (for standby screenshots)

    var aspectRatio: CGFloat {
        switch self {
        case .portrait: return 600.0 / 1238.0
        case .landscape: return 1238.0 / 600.0
        }
    }

    var originalWidth: CGFloat {
        switch self {
        case .portrait: return 600
        case .landscape: return 1238
        }
    }

    var originalHeight: CGFloat {
        switch self {
        case .portrait: return 1238
        case .landscape: return 600
        }
    }
}

/// Represents a tap indicator dot position relative to screenshot coordinates
struct TapDot: Identifiable {
    let id = UUID()
    let x: CGFloat  // relative to original screenshot width
    let y: CGFloat  // relative to original screenshot height

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// Represents a single screenshot with optional tap indicator dots
struct ScreenshotItem: Identifiable {
    let id = UUID()
    let image: Image
    let dots: [TapDot]
    let orientation: ScreenshotOrientation

    init(image: Image, dots: [TapDot] = [], orientation: ScreenshotOrientation = .portrait) {
        self.image = image
        self.dots = dots
        self.orientation = orientation
    }
}

// MARK: - Single Screenshot View

/// Displays a single screenshot with optional pulsing dot overlays
struct SingleScreenshotView: View {
    let item: ScreenshotItem

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // System background for transparent PNG screenshots
                Color(uiColor: .systemBackground)

                item.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                // Overlay dots at calculated positions
                ForEach(item.dots) { dot in
                    PulsingDotView()
                        .position(
                            x: (dot.x / item.orientation.originalWidth) * geometry.size.width,
                            y: (dot.y / item.orientation.originalHeight) * geometry.size.height
                        )
                }
            }
        }
        .aspectRatio(item.orientation.aspectRatio, contentMode: .fit)
    }
}

// MARK: - Page Indicator View

/// Custom page indicator dots for the carousel
struct PageIndicatorView: View {
    let totalPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.appAccent : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Screenshot Carousel View

/// A container that displays screenshots with optional pulsing dot overlays.
/// Single image: static display. Multiple images: horizontal carousel with paging.
struct ScreenshotCarouselView: View {
    let screenshots: [ScreenshotItem]
    @State private var currentIndex = 0

    var body: some View {
        if screenshots.isEmpty {
            EmptyView()
        } else if screenshots.count == 1 {
            SingleScreenshotView(item: screenshots[0])
        } else {
            VStack(spacing: 16) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(screenshots.enumerated()), id: \.element.id) { index, item in
                        SingleScreenshotView(item: item)
                            .tag(index)
                            .padding(.horizontal, 16)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicators
                PageIndicatorView(totalPages: screenshots.count, currentPage: currentIndex)
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Portrait Screenshot") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/Regular"),
            dots: [TapDot(x: 300, y: 167)]
        )
    ])
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Multiple Screenshots Carousel") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/Regular"),
            dots: [TapDot(x: 525, y: 67)]
        ),
        ScreenshotItem(
            image: Image("Onboarding/Minimized")
        )
    ])
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Landscape Screenshot (Standby)") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/WidgetStandby1"),
            orientation: .landscape
        )
    ])
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Mixed Orientations") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/WidgetHomeScreen1")
        ),
        ScreenshotItem(
            image: Image("Onboarding/WidgetLockScreen")
        ),
        ScreenshotItem(
            image: Image("Onboarding/WidgetStandby1"),
            orientation: .landscape
        )
    ])
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Screenshot with Multiple Dots") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/Sharing"),
            dots: [
                TapDot(x: 525, y: 67),
                TapDot(x: 75, y: 67)
            ]
        )
    ])
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}
