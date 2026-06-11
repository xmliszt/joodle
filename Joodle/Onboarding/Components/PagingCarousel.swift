//
//  PagingCarousel.swift
//  Joodle
//

import SwiftUI

/// A reusable auto-advancing paged carousel.
///
/// Owns the paging mechanics that both the onboarding screenshot carousel and
/// the changelog header carousel need: a paging `ScrollView` driven by
/// `scrollPosition(id:)`, a non-lazy `HStack` so the outgoing page slides off
/// instead of being culled, an auto-advance timer with a progress ramp, and the
/// `PageIndicatorView` underneath.
///
/// `PageTabViewStyle` is deliberately avoided: it cannot animate *programmatic*
/// selection changes (only user swipes), so a timer-driven advance pops the next
/// page in. `scrollPosition(id:)` animates programmatic changes wrapped in
/// `withAnimation`, giving a real slide in both directions.
///
/// Callers supply only the per-page content and a couple of layout knobs. A page
/// can opt into *external timing* (e.g. a video that reports its own playback
/// position and advances when it ends) so the image timer stays off for it.
struct PagingCarousel<Content: View>: View {
    let pageCount: Int
    var autoScrollInterval: TimeInterval = 5.0
    /// Fixed aspect ratio for the paging area; `nil` greedily fills the available
    /// space (aspect-fit content centres within it).
    var aspectRatio: CGFloat? = nil
    /// Horizontal inset on each page so neighbouring items keep a gap instead of
    /// sitting edge-to-edge as the carousel pages.
    var itemPadding: CGFloat = 16
    /// Vertical spacing between the paging area and the page indicator.
    var spacing: CGFloat = 16
    /// Per-page: `true` when the page drives its own progress + advance (e.g. a
    /// video), so the auto-advance timer and progress ramp stay off while it is
    /// the active page.
    var usesExternalTiming: (Int) -> Bool = { _ in false }
    /// Builds the content for a page. `isActive` is the visible page; bind
    /// `progress` for externally-timed pages; call `advance` when an
    /// externally-timed page ends.
    @ViewBuilder var content: (_ index: Int, _ isActive: Bool, _ progress: Binding<Double>, _ advance: @escaping () -> Void) -> Content

    @State private var currentIndex = 0
    /// Bound to the paging scroll view. Programmatic changes wrapped in
    /// `withAnimation` slide the next page in.
    @State private var scrolledIndex: Int?
    @State private var autoScrollTimer: Timer?
    /// Drives the active page's pill fill — a linear ramp over the interval for
    /// timer-paced pages, or real playback position for externally-timed ones.
    @State private var pageProgress: Double = 0

    var body: some View {
        VStack(spacing: spacing) {
            pagingArea
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrolledIndex)
                .scrollIndicators(.hidden)
                .onAppear {
                    scrolledIndex = currentIndex
                    startAutoScroll()
                }
                .onDisappear { stopAutoScroll() }
                .onChange(of: scrolledIndex) { _, newValue in
                    // Fired by both auto-advance and manual swipes. Sync the
                    // active page and reset the timer so the next auto-advance
                    // is a full interval away from wherever we landed.
                    guard let newValue, newValue != currentIndex else { return }
                    currentIndex = newValue
                    restartAutoScroll()
                }

            PageIndicatorView(
                totalPages: pageCount,
                currentPage: currentIndex,
                progress: pageProgress
            )
        }
    }

    @ViewBuilder
    private var pagingArea: some View {
        let scroll = ScrollView(.horizontal) {
            // Non-lazy so the outgoing page stays alive and slides off screen.
            // A LazyHStack culls it the moment it leaves the viewport, making it
            // pop out instead of sliding.
            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { index in
                    content(index, index == currentIndex, $pageProgress, advance)
                        // Centre the content in the page and let it fill the box.
                        // Content is responsible for its own aspect-fit (images
                        // and the video layer already fit, never cropping), so we
                        // don't impose `.scaledToFit()` here — that only works for
                        // content with a clean intrinsic aspect ratio and would
                        // collapse GeometryReader- or representable-backed content.
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // Horizontal inset keeps a gap between neighbouring items
                        // while each page still spans the full viewport so paging
                        // snaps one item at a time.
                        .padding(.horizontal, itemPadding)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }

        if let aspectRatio {
            scroll
                .frame(maxWidth: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            // Greedy height gives `containerRelativeFrame` a concrete size to
            // resolve against.
            scroll
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Auto-scroll

    private func startAutoScroll() {
        guard pageCount > 1 else { return }
        // Reset the fill so a fresh page always starts empty.
        pageProgress = 0
        // An externally-timed page reports its own position and advances itself
        // when it ends — leave the timer off so the two don't fight.
        guard !usesExternalTiming(currentIndex) else { return }
        guard autoScrollInterval > 0 else { return }
        animatePageProgress()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: false) { _ in
            advance()
        }
    }

    private func advance() {
        guard pageCount > 1 else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            scrolledIndex = (currentIndex + 1) % pageCount
        }
    }

    /// Resets the pill fill to empty, then ramps it to full over the interval
    /// (reset committed in its own transaction so the ramp animates from 0).
    private func animatePageProgress() {
        pageProgress = 0
        DispatchQueue.main.async {
            withAnimation(.linear(duration: autoScrollInterval)) {
                pageProgress = 1
            }
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    private func restartAutoScroll() {
        stopAutoScroll()
        startAutoScroll()
    }
}
