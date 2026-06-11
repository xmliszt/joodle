//
//  ChangelogDetailView.swift
//  Joodle
//
//  Created by Claude on 2025.
//

import SwiftUI
import UIKit
import AVFoundation
import MarkdownUI

/// Detail view for a single changelog entry, used in Settings navigation
struct ChangelogDetailView: View {
    let entry: ChangelogEntry

    var body: some View {
        content
            .onAppear {
                // Track changelog viewed
                AnalyticsManager.shared.trackChangelogViewed(version: entry.version)
            }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with date and version
              VStack(alignment: .leading) {
                  Text(entry.displayHeader)
                    .font(.appCaption())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                }

                // Optional Header Images (hidden when empty)
                if !entry.headerImageURLs.isEmpty {
                    HeaderImageCarouselView(urls: entry.headerImageURLs)
                        .padding()
                }

                // Markdown Content
                Markdown(entry.markdownContent)
                .markdownTheme(.docC)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

#Preview ("Without Image") {
    NavigationStack {
      ZStack {
        Color.gray
        .edgesIgnoringSafeArea(.all)

        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURLs: [],
                markdownContent: """
                ## ✨ What's New

                - **Feature 1**: Description of feature 1
                - **Feature 2**: Description of feature 2

                ---
                ## 🐛 Bug Fixes

                - Fixed an issue with sync
                - Improved performance
                """
            )
        )
      }

    }
}


// MARK: - Header Image Carousel

/// Auto-scrolling carousel of header images for a changelog entry.
/// Hides page indicators when there is only one image.
struct HeaderImageCarouselView: View {
    let urls: [URL]
    var autoScrollInterval: TimeInterval = 5.0

    /// Fixed corner radius for every carousel item.
    private let itemCornerRadius: CGFloat = 32

    /// Fixed container shape for every item. Media that doesn't match it
    /// letterboxes inside, with the corner-sampled fill keeping the rounded
    /// corners visible (see `CarouselVideoModel.backgroundColor`).
    private let itemAspectRatio: CGFloat = 9.0 / 16.0

    /// True when the URL points at a video container we play with AVPlayer
    /// rather than render as a (possibly animated) image.
    private func isVideo(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    var body: some View {
        if urls.count == 1, let url = urls.first {
            singleMediaView(url: url)
                .frame(maxWidth: .infinity)
        } else {
            // Paging mechanics + auto-advance live in PagingCarousel. Video pages
            // opt into external timing so they drive their own progress/advance.
            PagingCarousel(
                pageCount: urls.count,
                autoScrollInterval: autoScrollInterval,
                aspectRatio: itemAspectRatio,
                spacing: 12,
                usesExternalTiming: { isVideo(urls[$0]) }
            ) { index, isActive, progress, advance in
                mediaView(url: urls[index], isActive: isActive, progress: progress, onEnded: advance)
            }
        }
    }

    /// Media for the single-item case (no pager / no auto-advance). A lone video
    /// loops; a lone image renders as before.
    @ViewBuilder
    private func singleMediaView(url: URL) -> some View {
        if isVideo(url) {
            CarouselVideoView(
                url: url,
                isActive: true,
                loops: true,
                cornerRadius: itemCornerRadius,
                fallbackAspectRatio: itemAspectRatio,
                progress: .constant(0),
                onEnded: {}
            )
        } else {
            imageView(url: url)
        }
    }

    /// A single paged item: a playing video (which drives `progress` and advances
    /// on end via `onEnded`) or an image.
    @ViewBuilder
    private func mediaView(url: URL, isActive: Bool, progress: Binding<Double>, onEnded: @escaping () -> Void) -> some View {
        if isVideo(url) {
            CarouselVideoView(
                url: url,
                isActive: isActive,
                loops: false,
                cornerRadius: itemCornerRadius,
                fallbackAspectRatio: itemAspectRatio,
                progress: progress,
                onEnded: onEnded
            )
        } else {
            imageView(url: url)
        }
    }

    private func imageView(url: URL) -> some View {
        AnimatedImageView(url: url)
            .clipShape(RoundedRectangle(cornerRadius: itemCornerRadius, style: .continuous))
    }
}

// MARK: - Carousel Video

/// Owns the `AVPlayer` for one carousel video page and publishes its normalized
/// playback position (0...1). Playback is muted — these are silent UI demos and
/// must not duck the user's audio. The view bridges `progress`/`isFinished` up
/// to the carousel only while its page is the active one.
private final class CarouselVideoModel: ObservableObject {
    let player = AVPlayer()
    @Published var progress: Double = 0
    @Published var isFinished = false
    /// True once the player item can render its first frame. Until then the
    /// video surface is blank, so the view covers it with a loading skeleton.
    @Published var isReady = false
    /// Colour sampled from a corner of the video's first frame. We fill the
    /// carousel item with it so the letterbox around a `.resizeAspect` video
    /// reads as the video's own background and the rounded corners stay visible.
    @Published var backgroundColor: Color = .clear
    /// Native aspect ratio (width / height) of the video, read from its first
    /// frame. Used to size the player to the video's own shape so it fits
    /// centred — a narrower/taller video keeps its full height and never crops.
    @Published var videoAspectRatio: CGFloat?
    /// True when this OS can't decode/display the video (e.g. an AV1 file on a
    /// device with no AV1 decoder): the first-frame decode fails or the ready
    /// item reports a zero `presentationSize`. The view shows a placeholder
    /// instead of a permanently blank surface.
    @Published var failedToDisplay = false

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var isConfigured = false
    /// Set when `restart()` is asked to play before the item is ready. The
    /// status observer consumes it once the item reaches `.readyToPlay`.
    private var shouldPlayWhenReady = false
    /// Tracks whether we've started playback at least once, so the first play
    /// skips the seek (the item is already at zero) and only loops/reactivations
    /// rewind. An early `seek(to: .zero)` before the layer presents its first
    /// frame can leave the surface blank on iOS 18.5.
    private var hasStarted = false

    func configure(url: URL) {
        guard !isConfigured else { return }
        isConfigured = true

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        loadBackgroundColor(url: url)

        // Flip the skeleton off only once the item can actually render a frame.
        // KVO callbacks can arrive off the main thread, so hop back to publish.
        // If a play was requested before the item was ready (the common case on
        // first appearance), start it now — seeking a not-yet-ready item can drop
        // its completion on some iOS versions, leaving the layer blank.
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReady = true
                // A ready item with a zero presentation size has no displayable
                // video track on this OS (e.g. AV1 with no hardware decoder), so
                // surface the placeholder instead of a blank box.
                if self.player.currentItem?.presentationSize == .zero {
                    self.failedToDisplay = true
                }
                if self.shouldPlayWhenReady { self.restart() }
            }
        }

        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self,
                  let duration = self.player.currentItem?.duration.seconds,
                  duration.isFinite, duration > 0 else { return }
            self.progress = min(1, max(0, time.seconds / duration))
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.progress = 1
            self?.isFinished = true
        }
    }

    func pause() { player.pause() }

    /// Grabs the first frame and samples its bottom-left pixel — for these UI
    /// demos the frame edge is the app's solid background, which is exactly the
    /// fill we want behind the letterboxed video.
    private func loadBackgroundColor(url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, result, _ in
            // A failed first-frame decode means this OS can't open the video's
            // format (e.g. AV1 without a hardware decoder) — flag it so the view
            // shows a placeholder rather than a blank surface.
            guard result == .succeeded, let cgImage else {
                if result == .failed {
                    DispatchQueue.main.async { self?.failedToDisplay = true }
                }
                return
            }
            // `appliesPreferredTrackTransform` orients the frame, so its pixel
            // dimensions reflect the displayed shape.
            let aspectRatio = cgImage.height > 0 ? CGFloat(cgImage.width) / CGFloat(cgImage.height) : nil
            let color = cgImage.cornerColor
            DispatchQueue.main.async {
                if let aspectRatio { self?.videoAspectRatio = aspectRatio }
                if let color { self?.backgroundColor = color }
            }
        }
    }

    /// Rewind to the start and play — used both on first activation and to loop
    /// a lone video. Waits for the seek to land before starting playback so
    /// AVPlayerItemDidPlayToEndTime fires reliably on every cycle.
    ///
    /// If the item isn't ready yet, defer playback to the status observer rather
    /// than seeking now: an early seek on a not-yet-ready item can drop its
    /// completion (notably on iOS 18.5), so `play()` would never fire and the
    /// surface would stay blank even after the skeleton clears.
    func restart() {
        guard player.currentItem?.status == .readyToPlay else {
            shouldPlayWhenReady = true
            return
        }
        shouldPlayWhenReady = false
        isFinished = false
        progress = 0
        // First play: the fresh item is already at zero, so play directly. An
        // early seek before the layer has presented a frame can strand the
        // surface blank on iOS 18.5. Loop/reactivation restarts rewind first.
        guard hasStarted else {
            hasStarted = true
            player.play()
            return
        }
        player.seek(to: .zero) { [weak self] _ in
            self?.player.play()
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObserver?.invalidate()
        player.pause()
    }
}

private extension CGImage {
    /// Colour of the bottom-left pixel. Renders the image into a 1×1 context
    /// whose origin (bottom-left) captures exactly that pixel. Returns `nil`
    /// when the pixel is transparent so callers can fall back to no fill.
    var cornerColor: Color? {
        var pixel: [UInt8] = [0, 0, 0, 0]
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(self, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let alpha = Double(pixel[3]) / 255
        guard alpha > 0 else { return nil }
        return Color(
            .sRGB,
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255,
            opacity: alpha
        )
    }
}

/// Plays a single carousel video. Only the active page plays; others pause so we
/// never run multiple decoders at once. While active, it feeds playback position
/// into `progress` and, on end, either loops (`loops`) or calls `onEnded` so the
/// carousel can advance.
private struct CarouselVideoView: View {
    let url: URL
    let isActive: Bool
    var loops: Bool = false
    var cornerRadius: CGFloat = 0
    /// Aspect ratio used only while the video's real shape is still loading, so
    /// the representable has a defined footprint instead of collapsing (a nil
    /// ratio here is `.scaledToFit()`, which collapses a no-intrinsic-size view).
    var fallbackAspectRatio: CGFloat
    @Binding var progress: Double
    var onEnded: () -> Void

    @StateObject private var model = CarouselVideoModel()

    var body: some View {
        VideoPlayerLayerView(
            player: model.player,
            cornerRadius: cornerRadius,
            backgroundFill: model.backgroundColor
        )
            // Size to the video's own shape so it fits centred and never crops:
            // a narrower/taller video keeps its full height with the sides free.
            // Until the first frame resolves we use the fallback ratio so the
            // layer keeps a footprint instead of collapsing.
            .aspectRatio(model.videoAspectRatio ?? fallbackAspectRatio, contentMode: .fit)
            .overlay {
                if model.failedToDisplay {
                    UnavailableMediaPlaceholder(cornerRadius: cornerRadius)
                        .transition(.opacity)
                } else if !model.isReady {
                    SweepingSkeletonView(cornerRadius: cornerRadius)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: model.isReady)
            .animation(.easeInOut(duration: 0.3), value: model.failedToDisplay)
            .onAppear {
                model.configure(url: url)
                if isActive { model.restart() }
            }
            .onChange(of: isActive) { _, active in
                if active { model.restart() } else { model.pause() }
            }
            .onChange(of: model.failedToDisplay) { _, failed in
                // A lone looping video that can't display would otherwise loop
                // invisibly forever; pause it. Carousel pages keep playing so
                // their end notification still advances past the broken page.
                if failed && loops { model.pause() }
            }
            .onReceive(model.$progress) { value in
                if isActive { progress = value }
            }
            .onChange(of: model.isFinished) { _, finished in
                guard finished else { return }
                if loops {
                    model.restart()
                } else if isActive {
                    onEnded()
                }
            }
            .onDisappear { model.pause() }
    }
}

/// Shown in place of a video this OS can't decode (e.g. an AV1 file on a device
/// with no AV1 decoder). A calm, static muted fill with a small slashed-video
/// glyph — clearly intentional rather than a broken/blank surface.
struct UnavailableMediaPlaceholder: View {
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay {
                Image(systemName: "video.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

/// Loading placeholder shown over a carousel item (video or remote image) until
/// its content is ready. A muted fill with a soft highlight band that sweeps
/// top-to-bottom on a loop, reading as a skeleton rather than a spinner so it
/// stays calm during the brief uncached load.
struct SweepingSkeletonView: View {
    var cornerRadius: CGFloat

    @State private var sweepDown = false

    /// Band height as a fraction of the available height.
    private let bandFraction: CGFloat = 0.5

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let bandHeight = height * bandFraction

            Rectangle()
                .fill(Color(uiColor: .secondarySystemFill))
                .overlay {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: bandHeight)
                    // Start fully above the top edge, finish fully below the
                    // bottom edge, so the highlight travels the whole surface.
                    .offset(y: sweepDown ? height : -bandHeight)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                        sweepDown = true
                    }
                }
        }
    }
}

/// Chromeless video surface (no transport controls), letterboxed to fit so
/// tutorial UI is never cropped.
///
/// The `AVPlayerLayer` is the view's *backing layer* (via `layerClass`) rather
/// than a sublayer synced in `layoutSubviews()`. Backing the view directly is
/// the most robust pattern — the layer's frame always tracks `bounds` with no
/// timing window where it can be zero-sized (a frequent cause of "audio plays
/// but video is blank"). Corner rounding and the letterbox fill are applied
/// natively on that layer (`cornerRadius` + `masksToBounds`) instead of with
/// SwiftUI's `.clipShape()`/`.compositingGroup()`, which would flatten the live
/// video into an offscreen buffer and render blank on iOS 18.x.
private struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var cornerRadius: CGFloat = 0
    /// Fill drawn behind the letterboxed video (the corner-sampled background
    /// colour), clipped to the same rounded corners.
    var backgroundFill: Color = .clear

    func makeUIView(context: Context) -> PlayerLayerUIView {
        PlayerLayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerLayerUIView, context: Context) {
        uiView.player = player
        uiView.cornerRadius = cornerRadius
        uiView.backgroundColor = UIColor(backgroundFill)
    }

    final class PlayerLayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        private var playerLayer: AVPlayerLayer {
            // Safe: `layerClass` guarantees the backing layer is an AVPlayerLayer.
            layer as! AVPlayerLayer
        }

        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        var cornerRadius: CGFloat = 0 {
            didSet {
                guard cornerRadius != oldValue else { return }
                playerLayer.cornerRadius = cornerRadius
                playerLayer.cornerCurve = .continuous
                playerLayer.masksToBounds = true
            }
        }

        init(player: AVPlayer) {
            super.init(frame: .zero)
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspect
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

#Preview ("With Image") {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURLs: [
                    URL(string: "https://joodle.liyuxuan.dev/changelogs/1.17.png")!
                ],
                markdownContent: """
                ## ✨ What's New

                - **Feature 1**: Description of feature 1
                - **Feature 2**: Description of feature 2

                ## 🐛 Bug Fixes

                - Fixed an issue with sync
                - Improved performance
                """
            )
        )
    }
}

#Preview ("With Multiple Images") {
    NavigationStack {
        ChangelogDetailView(
            entry: ChangelogEntry(
                version: "1.0.54",
                major: 1,
                minor: 0,
                build: 54,
                date: Date(),
                headerImageURLs: [
                    URL(string: "https://joodle.liyuxuan.dev/changelogs/1.17.png")!,
                    URL(string: "https://joodle.liyuxuan.dev/changelogs/1.16.png")!
                ],
                markdownContent: """
                ## ✨ What's New

                - **Feature 1**: Description of feature 1
                - **Feature 2**: Description of feature 2

                ## 🐛 Bug Fixes

                - Fixed an issue with sync
                - Improved performance
                """
            )
        )
    }
}

/// Mirrors the real "What's New" presentation in `JoodleApp` — the changelog in
/// a bottom sheet (medium/large detents) — so we can see the carousel auto-play
/// the two demo videos and drive the page indicator from real playback position.
#Preview ("Bottom Sheet · Video Carousel") {
    struct BottomSheetPreviewHost: View {
        @State private var entry: ChangelogEntry? = ChangelogEntry(
            version: "2.0",
            major: 2,
            minor: 0,
            build: 0,
            date: Date(),
            headerImageURLs: [
                URL(string: "https://joodle.liyuxuan.dev/changelogs/2.0_1.mp4")!,
                URL(string: "https://joodle.liyuxuan.dev/changelogs/2.0_2.mp4")!,
                URL(string: "https://joodle.liyuxuan.dev/changelogs/1.17.png")!,
                URL(string: "https://joodle.liyuxuan.dev/changelogs/1.17.png")!
            ],
            markdownContent: """
            ## ✨ What's New in 2.0

            - **Video walkthroughs**: See new features in motion right here
            - **Smarter sync**: Faster and more reliable across devices

            ## 🐛 Bug Fixes

            - Squashed a handful of layout glitches
            - Improved performance
            """
        )

        var body: some View {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .sheet(item: $entry) { entry in
                    NavigationStack {
                        ChangelogDetailView(entry: entry)
                            .navigationTitle("What's New")
                            .navigationBarTitleDisplayMode(.large)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
        }
    }

    return BottomSheetPreviewHost()
}
