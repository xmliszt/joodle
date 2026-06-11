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

/// Image source for a screenshot - either local asset or remote URL
enum ScreenshotImageSource {
    case local(Image)
    case remote(URL)
}

/// Represents a single screenshot with optional tap indicator dots
struct ScreenshotItem: Identifiable {
    let id = UUID()
    let imageSource: ScreenshotImageSource
    let dots: [TapDot]
    let orientation: ScreenshotOrientation

    /// Initialize with a local Image
    init(image: Image, dots: [TapDot] = [], orientation: ScreenshotOrientation = .portrait) {
        self.imageSource = .local(image)
        self.dots = dots
        self.orientation = orientation
    }

    /// Initialize with a remote URL
    init(url: URL, dots: [TapDot] = [], orientation: ScreenshotOrientation = .portrait) {
        self.imageSource = .remote(url)
        self.dots = dots
        self.orientation = orientation
    }

    /// Convenience initializer with URL string
    init(urlString: String, dots: [TapDot] = [], orientation: ScreenshotOrientation = .portrait) {
        if let url = URL(string: urlString) {
            self.imageSource = .remote(url)
        } else {
            // Fallback to a placeholder if URL is invalid
            self.imageSource = .local(Image(systemName: "photo.trianglebadge.exclamationmark.fill"))
        }
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

                screenshotImage
                    // Fit (not fill) so a screenshot whose real aspect ratio
                    // differs from its declared orientation is scaled down and
                    // centered rather than cropped.
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

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

    @ViewBuilder
    private var screenshotImage: some View {
        switch item.imageSource {
        case .local(let image):
          image.resizable()
        case .remote(let url):
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                case .failure:
                    Image(systemName: "photo")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Page Indicator View

/// Carousel page indicator. Inactive pages render as small dots; the active
/// page morphs into a pill whose accent fill grows left-to-right to reflect
/// `progress` (0...1) — the advance timer for an image, or playback position
/// for a video.
struct PageIndicatorView: View {
    let totalPages: Int
    let currentPage: Int
    /// Fill progress of the active page's pill, clamped to 0...1.
    var progress: Double = 0
    /// When true, the active page morphs into a progress pill. When false, it
    /// stays a dot (accent-filled) — for items with no duration to visualize,
    /// e.g. static-image share card styles.
    var activeShowsProgress: Bool = true

    private let dotSize: CGFloat = 6
    private let pillWidth: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                let isActive = index == currentPage
                let showsPill = isActive && activeShowsProgress
                Capsule()
                    // Active-but-no-progress reads as a solid accent dot; everything
                    // else is the muted track (with the pill's accent fill on top).
                    .fill(isActive && !showsPill ? Color.appAccent : Color.secondary.opacity(0.3))
                    .frame(width: showsPill ? pillWidth : dotSize, height: dotSize)
                    .overlay(alignment: .leading) {
                        // Accent fill only on the active pill. Starts at a full
                        // dot so the morph reads as the dot sweeping rightward.
                        if showsPill {
                            // Grow from a full dot to the full pill so the accent
                            // advances immediately — interpolating the *range*
                            // [dotSize, pillWidth] avoids the dead zone you'd get
                            // from flooring `pillWidth * progress` at `dotSize`.
                            Capsule()
                                .fill(Color.appAccent)
                                .frame(
                                    width: dotSize + (pillWidth - dotSize) * min(1, max(0, progress)),
                                    height: dotSize
                                )
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        // Animate at the container level so the morphing pill *and* the resulting
        // displacement of the sibling dots slide together. Keyed to the active
        // page (and whether it shows a pill) — never to `progress`, so the fill
        // ramp stays driven by its own clock without springing.
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: activeShowsProgress)
    }
}

// MARK: - Screenshot Carousel View

/// A container that displays screenshots with optional pulsing dot overlays.
/// Single image: static display. Multiple images: horizontal carousel with paging.
struct ScreenshotCarouselView: View {
    let screenshots: [ScreenshotItem]
    var autoScrollInterval: TimeInterval = 5.0

    var body: some View {
        if screenshots.isEmpty {
            EmptyView()
        } else if screenshots.count == 1 {
            SingleScreenshotView(item: screenshots[0])
        } else {
            PagingCarousel(
                pageCount: screenshots.count,
                autoScrollInterval: autoScrollInterval
            ) { index, _, _, _ in
                SingleScreenshotView(item: screenshots[index])
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Portrait Screenshot") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/WidgetHomeScreen1"),
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
            image: Image("Onboarding/WidgetHomeScreen1"),
            dots: [TapDot(x: 525, y: 67)]
        ),
        ScreenshotItem(
            image: Image("Onboarding/WidgetHomeScreen1")
        )
    ])
    .padding(.horizontal, 24)
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Landscape Screenshot (Standby)") {
    ScreenshotCarouselView(screenshots: [
        ScreenshotItem(
            image: Image("Onboarding/WidgetHomeScreen1"),
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
            image: Image("Onboarding/WidgetHomeScreen1"),
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
