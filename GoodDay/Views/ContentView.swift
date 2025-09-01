//
//  ContentView.swift
//  GoodDay
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @Environment(UserPreferences.self) private var userPreferences

  @Query private var entries: [DayEntry]

  @State private var selectedDateItem: DateItem?
  @State private var dragLocation: CGPoint = .zero
  @State private var isDragging = false
  @State private var highlightedId: String?
  @State private var isScrollingDisabled = false
  @State private var viewMode: ViewMode = UserPreferences.shared.defaultViewMode
  @State private var yearGridViewSize: CGSize = .zero
  @State private var scrollProxy: ScrollViewProxy?
  @State private var showDrawingCanvas: Bool = false

  // Touch delay detection states
  @State private var touchStartTime: Date?
  @State private var initialTouchLocation: CGPoint = .zero
  @State private var hasMovedBeforeDelay = false
  @State private var isInDelayPeriod = false
  @State private var delayTimer: Timer?
  @State private var initialTouchItemId: String?

  @State private var selectedYear = Calendar.current.component(.year, from: Date())
  @State private var navigateToSettings = false
  @State private var hideDynamicIslandView = false
  private let headerHeight: CGFloat = 100.0

  // Hit testing optimization
  @State private var hitTestingGrid: [[String?]] = []
  @State private var gridMetrics: GridMetrics?

  struct GridMetrics {
    let rowHeight: CGFloat
    let colWidth: CGFloat
    let startX: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
  }

  // Pinch gesture states
  private let scaleThreshold: CGFloat = 0.9  // Threshold for detecting significant pinch
  private let expandThreshold: CGFloat = 1.2  // Threshold for detecting significant expand
  @State private var isPinching = false

  // MARK: Computed
  /// Flattened array of items to be displayed in the year grid.
  private var itemsInYear: [DateItem] {
    let calendar = Calendar.current
    let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
    let daysCount = daysInYear

    return (0..<daysCount).map { dayOffset in
      let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfYear)!
      return DateItem(
        id: "\(Int(date.timeIntervalSince1970))",
        date: date
      )
    }
  }

  var body: some View {
    ZStack {
      GeometryReader { geometry in
        // Calculate spacing for the grid based on geometry values
        let itemsSpacing = calculateSpacing(containerWidth: geometry.size.width, viewMode: viewMode)

        ZStack(alignment: .top) {
          ResizableSplitView(
            top: {
              // Full-screen scrollable year grid
              ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                  // Add spacer at top to account for header overlay
                  Spacer()
                    .frame(height: headerHeight)
                    .id("topSpacer")

                  YearGridView(
                    year: selectedYear,
                    viewMode: viewMode,
                    dotsSpacing: itemsSpacing,
                    items: itemsInYear,
                    entries: entries,
                    highlightedItemId: highlightedId
                  )
                  .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                      .onChanged { handleDragChanged(value: $0, geometry: geometry) }
                      .onEnded {
                        handleDragEnded(value: $0, geometry: geometry, scrollProxy: scrollProxy)
                      }
                  )
                  .simultaneousGesture(
                    MagnificationGesture()
                      .onChanged { handlePinchChanged(value: $0) }
                      .onEnded { handlePinchEnded(value: $0) }
                  )
                }
                .scrollDisabled(isScrollingDisabled || isPinching)
                .background(.backgroundColor)
                // When view mode change, scroll to today's dot and rebuild hit testing grid
                .onChange(of: viewMode) {
                  hitTestingGrid = []  // Clear grid to trigger rebuild
                  gridMetrics = nil
                  scrollToRelevantDate(date: Date(), scrollProxy: scrollProxy)
                }
                // When year changes, scroll to relevant date and rebuild hit testing grid
                .onChange(of: selectedYear) {
                  hitTestingGrid = []  // Clear grid to trigger rebuild
                  gridMetrics = nil
                  scrollToRelevantDate(date: Date(), scrollProxy: scrollProxy)
                }
                // Initial scroll to today's dot for both modes
                .onAppear {
                  yearGridViewSize = geometry.size
                  self.scrollProxy = scrollProxy
                  scrollToRelevantDate(date: Date(), scrollProxy: scrollProxy)
                }
                // When device orientation changes, scroll to today's dot and rebuild hit testing grid
                .onRotate { _ in
                  yearGridViewSize = geometry.size
                  hitTestingGrid = []  // Clear grid to trigger rebuild
                  gridMetrics = nil
                  scrollToRelevantDate(date: Date(), scrollProxy: scrollProxy)
                }
                .onDisappear {
                  self.scrollProxy = nil
                }
              }
            },
            bottom: {
              EntryEditingView(
                date: selectedDateItem?.date,
                onOpenDrawingCanvas: {
                  Haptic.play()
                  showDrawingCanvas = true
                },
                onFocusChange: { isFocused in
                  guard isFocused, let selectedDateItem, let scrollProxy else { return }
                  scrollToRelevantDate(date: selectedDateItem.date, scrollProxy: scrollProxy)
                }
              )
            }, hasBottomView: selectedDateItem != nil,
            onBottomDismissed: {
              selectedDateItem = nil
            },
            onTopViewHeightChange: { newHeight in
              yearGridViewSize.height = newHeight
              guard let selectedDateItem, let scrollProxy else { return }
              scrollToRelevantDate(date: selectedDateItem.date, scrollProxy: scrollProxy)
            }
          )
          .frame(alignment: .top)
          .ignoresSafeArea(.container, edges: .bottom)

          // Floating header with blur backdrop
          HeaderView(
            highlightedEntry: highlightedId != nil
              ? (entries.first(where: { $0.createdAt == getItem(from: highlightedId!)?.date }))
              : nil,
            geometry: geometry,
            highlightedItem: highlightedId != nil ? getItem(from: highlightedId!) : nil,
            selectedYear: $selectedYear,
            viewMode: viewMode,
            onToggleViewMode: toggleViewMode,
            onSettingsAction: {
              navigateToSettings = true
            }
          )
        }
        .background(.backgroundColor)
        .onShake {
          handleShakeGesture()
        }
      }
      .ignoresSafeArea(.all, edges: .bottom)
      // Present drawing canvas
      .sheet(
        isPresented: Binding<Bool>(
          // Only present the sheet when device has no dynamic island
          get: { showDrawingCanvas && !UIDevice.hasDynamicIsland },
          set: { showDrawingCanvas = $0 }
        )
      ) {
        DrawingCanvasView(
          date: selectedDateItem!.date,
          entry: entries.first(where: { $0.createdAt == selectedDateItem!.date }),
          onDismiss: {
            showDrawingCanvas = false
          },
          isShowing: showDrawingCanvas && !UIDevice.hasDynamicIsland
        )
        .disabled(selectedDateItem == nil)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(UIDevice.screenCornerRadius)
      }
      // Navigate to setting view
      .navigationDestination(isPresented: $navigateToSettings) {
        SettingsView()
          .environment(userPreferences)
      }
      .onChange(of: navigateToSettings) { _, newValue in
        // If setting presented, hide dynamic island view
        if newValue == true {
          hideDynamicIslandView = true
        }
        // If setting dismissed, show dynamic island view after a short delay
        else {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            hideDynamicIslandView = false
          }
        }
      }

      // Dynamic island drawing canvas view
      if UIDevice.hasDynamicIsland && selectedDateItem != nil {
        DynamicIslandExpandedView(
          isExpanded: $showDrawingCanvas,
          content: {
            DrawingCanvasView(
              date: selectedDateItem!.date,
              entry: entries.first(where: { $0.createdAt == selectedDateItem!.date }),
              onDismiss: {
                showDrawingCanvas = false
              },
              isShowing: showDrawingCanvas
            )
          },
          // Hide dynamic island view when navigate to setting
          hidden: hideDynamicIslandView,
          onDismiss: {
            showDrawingCanvas = false
          }
        )
        .id("DynamicIslandExpandedView-\(selectedDateItem?.id ?? "none")")
      }
    }
  }

  /// Number of days in the selected year
  private var daysInYear: Int {
    let calendar = Calendar.current
    let startOfYear = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
    let startOfNextYear = calendar.date(
      from: DateComponents(year: selectedYear + 1, month: 1, day: 1))!
    return calendar.dateComponents([.day], from: startOfYear, to: startOfNextYear).day!
  }

  /// Calculate spacing between dots based on view mode
  private func calculateSpacing(containerWidth: CGFloat, viewMode: ViewMode) -> CGFloat {
    let gridWidth = containerWidth - (2 * GRID_HORIZONTAL_PADDING)
    let totalDotsWidth = viewMode.dotSize * CGFloat(viewMode.dotsPerRow)
    let availableSpace = gridWidth - totalDotsWidth
    let spacing = availableSpace / CGFloat(viewMode.dotsPerRow - 1)

    // Apply minimum spacing based on view mode
    let minimumSpacing: CGFloat = viewMode == .now ? 4 : 2
    return max(minimumSpacing, spacing)
  }

  // MARK: User interactions
  private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
    // Don't process drag gestures while pinching
    if isPinching { return }

    dragLocation = value.location

    // Check if this is the start of a drag gesture
    if !isDragging {
      isDragging = true
      touchStartTime = Date()
      initialTouchLocation = value.location
      hasMovedBeforeDelay = false
      isInDelayPeriod = true
      // Store the initial item ID for later use in timer
      initialTouchItemId = getItemId(at: value.location, for: geometry)
      // Ensure scrolling is enabled at the start
      isScrollingDisabled = false

      // Start the delay timer
      startDelayTimer()
    } else {
      // Check if user has moved significantly during the delay period
      if isInDelayPeriod {
        let movementThreshold: CGFloat = 5  // pixels - very small threshold for quick response
        let distanceMoved = sqrt(
          pow(value.location.x - initialTouchLocation.x, 2)
            + pow(value.location.y - initialTouchLocation.y, 2)
        )

        if distanceMoved > movementThreshold {
          hasMovedBeforeDelay = true
          cancelDelayTimer()
          isInDelayPeriod = false
          // Allow normal scrolling by ensuring scroll is enabled
          isScrollingDisabled = false
          highlightedId = nil
        }
      }
    }

    // Only highlight dots if scrolling is disabled (after delay without movement)
    if isScrollingDisabled && !isInDelayPeriod {
      let newHighlightedId = getItemId(at: value.location, for: geometry)

      // Haptic feedback when selection changes between dots
      // Only feedback when the highlighted id changes
      if newHighlightedId != highlightedId { Haptic.play() }

      // Update highlightedId
      highlightedId = newHighlightedId
    }
  }

  private func handleDragEnded(
    value: DragGesture.Value, geometry: GeometryProxy, scrollProxy: ScrollViewProxy
  ) {
    // Don't process drag gestures while pinching
    if isPinching { return }

    // Check if this was a tap (no movement and very short duration)
    let wasTap =
      !hasMovedBeforeDelay && !isScrollingDisabled
      && (touchStartTime.map { Date().timeIntervalSince($0) < 0.2 } ?? false)

    // Select date
    if let highlightedId, let item = getItem(from: highlightedId) {
      selectDateItem(item: item, scrollProxy: scrollProxy)
    }

    // Clean up all touch-related state
    cancelDelayTimer()
    isDragging = false
    isScrollingDisabled = false
    highlightedId = nil
    isInDelayPeriod = false
    hasMovedBeforeDelay = false
    touchStartTime = nil
    initialTouchItemId = nil

    // If it was a tap, handle date selection
    if !wasTap { return }
    guard let itemId = getItemId(at: value.location, for: geometry) else { return }
    guard let item = getItem(from: itemId) else { return }
    selectDateItem(item: item, scrollProxy: scrollProxy)

    // Haptic feedback
    Haptic.play()
  }

  private func handlePinchChanged(value: MagnificationGesture.Value) {
    if isPinching { return }

    isPinching = true

    // Clean up any ongoing drag gesture state when pinch begins
    highlightedId = nil
    isScrollingDisabled = false
    cancelDelayTimer()
    isInDelayPeriod = false
    hasMovedBeforeDelay = false
    isDragging = false
  }

  private func handlePinchEnded(value: MagnificationGesture.Value) {
    isPinching = false
    highlightedId = nil
    isScrollingDisabled = false

    // Pinch in: switch from "now" to "year" mode
    if value < scaleThreshold && viewMode == .now {
      toggleViewMode(to: .year)
    }
    // Pinch out: switch from "year" to "now" mode
    else if value > expandThreshold && viewMode == .year {
      toggleViewMode(to: .now)
    }
  }

  // MARK: Utils
  /// Get the item id for a particular CGPoint location using pre-calculated hit testing grid
  private func getItemId(at location: CGPoint, for geometry: GeometryProxy) -> String? {
    // Use fast O(1) lookup if grid is built
    if let metrics = gridMetrics, !hitTestingGrid.isEmpty {
      return getItemIdFromGrid(at: location, metrics: metrics)
    }

    // Fallback to original method and rebuild grid
    buildHitTestingGrid(for: geometry)
    if let metrics = gridMetrics {
      return getItemIdFromGrid(at: location, metrics: metrics)
    }

    return getItemIdLegacy(at: location, for: geometry)
  }

  /// Fast O(1) hit testing using pre-built grid
  private func getItemIdFromGrid(at location: CGPoint, metrics: GridMetrics) -> String? {
    let adjustedLocation = adjustTouchLocationForGrid(location)
    let adjustedX = adjustedLocation.x - metrics.offsetX
    let adjustedY = adjustedLocation.y - metrics.offsetY

    // Account for dot centering - dots are positioned with their centers, so we need to
    // adjust hit testing to match. We need half spacing + half dot size + adjusted Y position
    let spacing = calculateSpacing(containerWidth: yearGridViewSize.width, viewMode: viewMode)
    let centeredY = adjustedY + (spacing / 2) + (viewMode.dotSize / 2)
    let row = max(0, Int(floor(centeredY / metrics.rowHeight)))
    let col = max(0, Int(floor(adjustedX / metrics.colWidth)))

    guard row < hitTestingGrid.count,
      col < hitTestingGrid[row].count
    else { return nil }

    return hitTestingGrid[row][col]
  }

  /// Build hit testing grid for fast lookups
  private func buildHitTestingGrid(for geometry: GeometryProxy) {
    let spacing = calculateSpacing(containerWidth: geometry.size.width, viewMode: viewMode)
    let containerWidth = geometry.size.width - (2 * GRID_HORIZONTAL_PADDING)
    let totalSpacingWidth = CGFloat(viewMode.dotsPerRow - 1) * spacing
    let totalDotWidth = containerWidth - totalSpacingWidth
    let itemSpacing = totalDotWidth / CGFloat(viewMode.dotsPerRow)

    let rowHeight = viewMode.dotSize + spacing
    let colWidth = itemSpacing + spacing
    let startX = itemSpacing / 2

    // Store metrics for fast access
    gridMetrics = GridMetrics(
      rowHeight: rowHeight,
      colWidth: colWidth,
      startX: startX,
      offsetX: startX - colWidth / 2,
      offsetY: 0  // No additional Y offset needed since we account for header in adjustTouchLocationForGrid
    )

    // Build 2D grid
    let numberOfRows = (itemsInYear.count + viewMode.dotsPerRow - 1) / viewMode.dotsPerRow
    hitTestingGrid = Array(
      repeating: Array(repeating: nil, count: viewMode.dotsPerRow), count: numberOfRows)

    for (index, item) in itemsInYear.enumerated() {
      let row = index / viewMode.dotsPerRow
      let col = index % viewMode.dotsPerRow
      hitTestingGrid[row][col] = item.id
    }
  }

  /// Legacy hit testing method (fallback)
  private func getItemIdLegacy(at location: CGPoint, for geometry: GeometryProxy) -> String? {
    let gridWidth = geometry.size.width
    let spacing = calculateSpacing(containerWidth: geometry.size.width, viewMode: viewMode)
    let adjustedLocation = adjustTouchLocationForGrid(location)
    let adjustedX = adjustedLocation.x
    // Account for dot centering in legacy method too - half spacing + half dot size + adjusted Y
    let adjustedY = adjustedLocation.y + (spacing / 2) + (viewMode.dotSize / 2)

    let containerWidth = gridWidth - (2 * GRID_HORIZONTAL_PADDING)
    let totalSpacingWidth = CGFloat(viewMode.dotsPerRow - 1) * spacing
    let totalDotWidth = containerWidth - totalSpacingWidth
    let itemSpacing = totalDotWidth / CGFloat(viewMode.dotsPerRow)
    let startX = itemSpacing / 2

    let rowHeight = viewMode.dotSize + spacing
    let row = max(0, Int(floor(adjustedY / rowHeight)))

    var closestCol = 0
    var minDistance = CGFloat.greatestFiniteMagnitude

    for col in 0..<viewMode.dotsPerRow {
      let xPos = startX + CGFloat(col) * (itemSpacing + spacing)
      let distance = abs(adjustedX - xPos)
      if distance < minDistance {
        minDistance = distance
        closestCol = col
      }
    }

    let col = max(0, min(viewMode.dotsPerRow - 1, closestCol))
    let itemIndex = row * viewMode.dotsPerRow + col

    guard itemIndex < itemsInYear.count else { return nil }

    let item = itemsInYear[itemIndex]
    return item.id
  }

  private func getItem(from itemId: String) -> DateItem? {
    return itemsInYear.first { $0.id == itemId }
  }

  private func selectDateItem(item: DateItem, scrollProxy: ScrollViewProxy) {
    // Initialize editedText with the entry content for the selected date
    var entry = entries.first { entry in
      Calendar.current.isDate(entry.createdAt, inSameDayAs: item.date)
    }

    // Create new entry if there's text content
    if entry == nil {
      entry = DayEntry(body: "", createdAt: item.date)
      modelContext.insert(entry!)
      try? modelContext.save()
    }

    selectedDateItem = item
    scrollToRelevantDate(date: item.date, scrollProxy: scrollProxy)
  }

  /// Toggle the view mode between current modes
  private func toggleViewMode() {
    // Use a spring animation for morphing effect
    withAnimation(.springFkingSatifying) {
      viewMode = viewMode == .now ? .year : .now
    }
  }

  /// Toggle the view mode to a specific mode
  private func toggleViewMode(to newViewMode: ViewMode) {
    // Use a spring animation for morphing effect
    withAnimation(.springFkingSatifying) {
      viewMode = newViewMode
      // Save the new view mode as the user's preference
      userPreferences.defaultViewMode = newViewMode
    }
  }

  // MARK: - Shake Gesture Handler
  private func handleShakeGesture() {
    let currentYear = Calendar.current.component(.year, from: Date())

    // Haptic feedback for shake action
    Haptic.play(with: .medium)

    // Set to current year and scroll to today
    withAnimation(.springFkingSatifying) {
      selectedYear = currentYear
      viewMode = .now  // Switch to "now" mode for better visibility
    }

    // Scroll to current day if turned on that feature
  }

  // MARK: - Touch Delay Timer Methods
  private func startDelayTimer() {
    // Cancel any existing timer
    cancelDelayTimer()

    // Start a new timer for 0.1 second delay
    delayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [self] _ in
      // Timer fired - user hasn't moved significantly within 0.1 second
      if !hasMovedBeforeDelay && isInDelayPeriod {
        // Enable dot highlighting mode
        isScrollingDisabled = true
        isInDelayPeriod = false

        // Set initial highlighted dot to stored initial touch item
        if let initialId = initialTouchItemId {
          highlightedId = initialId
        }

        // Provide haptic feedback to indicate mode switch
        Haptic.play(with: .medium)
      }
    }
  }

  private func cancelDelayTimer() {
    delayTimer?.invalidate()
    delayTimer = nil
  }

  // MARK: Layout Calculations
  /// Scrolls to center the most relevant date (today if in selected year, otherwise first day of year)
  private func scrollToRelevantDate(date: Date, scrollProxy: ScrollViewProxy) {
    // Only auto-scroll if the preference is enabled
    guard userPreferences.autoScrollRelevantDate else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      let currentYear = Calendar.current.component(.year, from: Date())

      withAnimation(.springFkingSatifying) {
        if selectedYear != currentYear {
          // For non-current years, scroll to the top spacer to show first row properly
          scrollProxy.scrollTo("topSpacer", anchor: .top)
        } else {
          // For current year, scroll to today with proper centering
          let targetId = getRelevantDateId(date: date)
          let anchor = calculateScrollAnchor(for: targetId, containerSize: yearGridViewSize)
          scrollProxy.scrollTo(targetId, anchor: anchor)
        }
      }
    }
  }

  private func getDateFromId(_ id: String) -> Date {
    guard let item = itemsInYear.first(where: { $0.id == id }) else {
      fatalError("Invalid item ID: \(id)")
    }
    return item.date
  }

  private func getFormattedDate(_ date: Date) -> String {
    return date.formatted(date: .abbreviated, time: .omitted)
  }

  /// Get the item ID for the most relevant date (today if in selected year, otherwise first day of year)
  private func getRelevantDateId(date: Date) -> String {
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: date)

    // If we're viewing the current year, try to scroll to today
    if selectedYear == currentYear {
      if let dateItem = itemsInYear.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
        return dateItem.id
      }
    }

    // Otherwise, scroll to the first day of the selected year
    return itemsInYear.first?.id ?? ""
  }

  /// Calculate the proper scroll anchor to center a dot on the visible screen
  /// This is because our grid view does not have virtualization, because we want to
  /// morph every single dot between view modes. Therefore, the grid view has height
  /// that is the sum of all dots' height, which could be longer than the screen height.
  /// Therefore, we need to calculate the scroll anchor to center the dot on the visible screen.
  /// Adjusts the touch location from the parent coordinate system to the grid's coordinate system
  private func adjustTouchLocationForGrid(_ location: CGPoint) -> CGPoint {
    // Adjust for the header height and horizontal padding
    return CGPoint(
      x: location.x - GRID_HORIZONTAL_PADDING,
      y: location.y
    )
  }

  private func calculateScrollAnchor(for itemId: String, containerSize: CGSize) -> UnitPoint {
    // Find the item index
    guard let item = itemsInYear.first(where: { $0.id == itemId }),
      let itemIndex = itemsInYear.firstIndex(where: { $0.id == item.id })
    else {
      return .top
    }

    // Calculate proper anchor to center the dot on screen (only used for current year)
    let spacing = calculateSpacing(containerWidth: containerSize.width, viewMode: viewMode)

    // Calculate dot position within the content
    let row = itemIndex / viewMode.dotsPerRow
    let dotYPosition = CGFloat(row) * (viewMode.dotSize + spacing)  // Add top padding

    // Calculate total content height
    let numberOfRows = (itemsInYear.count + viewMode.dotsPerRow - 1) / viewMode.dotsPerRow
    let totalContentHeight = CGFloat(numberOfRows) * (viewMode.dotSize + spacing)

    // Calculate what percentage down the content the dot should be to appear in screen center
    let scrollPercentage = max(0, min(1, dotYPosition / totalContentHeight))

    // Return anchor point that will center the dot on visible screen
    return UnitPoint(x: 0.5, y: scrollPercentage)
  }
}

#Preview {
  ContentView()
    .modelContainer(for: DayEntry.self, inMemory: true)
    .environment(UserPreferences.shared)
    .preferredColorScheme(.light)
}
