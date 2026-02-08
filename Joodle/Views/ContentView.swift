//
//  ContentView.swift
//  Joodle
//
//  Created by Li Yuxuan on 10/8/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.userPreferences) private var userPreferences
  @Environment(\.cloudSyncManager) private var cloudSyncManager

  @Query private var entries: [DayEntry]
  @StateObject private var subscriptionManager = SubscriptionManager.shared

  /// Grace period manager for one-time expired paywall
  @StateObject private var gracePeriodManager = GracePeriodManager.shared

  /// Data provider for the grid (abstracts data source for shared JoodleGridInteractionView)
  @StateObject private var dataProvider = AppDataProvider()

  @Binding var selectedDateFromWidget: Date?

  // --- GESTURE STATE ---
  // Tracks what the user is currently doing
  @State private var isScrubbing = false
  @State private var isPinching = false
  @State private var highlightedId: String?
  // --- END GESTURE STATE ---

  @State private var yearGridViewSize: CGSize = .zero
  @State private var scrollProxy: ScrollViewProxy?
  @State private var showDrawingCanvas: Bool = false
  @State private var showNotePromptPopup: Bool = false
  @State private var dateForNotePrompt: Date? = nil
  /// Tracks whether the entry had a doodle when the drawing canvas was opened (for note prompt logic)
  @State private var entryHadDoodleOnCanvasOpen: Bool = false

  @State private var navigateToSettings = false
  @State private var navigateToNotePromptSetting = false
  @State private var hideDynamicIslandView = false
  @State private var showGraceExpiredPaywall = false
  private let headerHeight: CGFloat = 100.0

  // Hit testing optimization (O(1) lookup)
  @State private var hitTestingGrid: [[String?]] = []
  @State private var gridMetrics: GridMetrics?

  struct GridMetrics {
    let rowHeight: CGFloat
    let colWidth: CGFloat
    let startX: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
  }

  // Gesture states
  private let scaleThreshold: CGFloat = 0.9  // Threshold for detecting significant pinch
  private let expandThreshold: CGFloat = 1.2  // Threshold for detecting significant expand

  // MARK: Computed

  private var currentHighlightedItem: DateItem? {
    highlightedId.flatMap { dataProvider.getItem(from: $0) }
  }

  private var currentHighlightedEntry: DayEntry? {
    if let itemDate = currentHighlightedItem?.date {
      return entries.first(where: { $0.matches(date: itemDate) })
    }
    return nil
  }

  /// Compute selectedEntry on-the-fly to avoid binding propagation issues
  private var selectedEntry: DayEntry? {
    guard let date = dataProvider.selectedDateItem?.date else { return nil }
    let candidates = entries.filter { $0.matches(date: date) }
    return candidates.first(where: { ($0.drawingData?.isEmpty == false) || !$0.body.isEmpty }) ?? candidates.first
  }

  private var isBottomViewVisible: Bool {
    dataProvider.selectedDateItem != nil
  }

  var body: some View {
    ZStack {
      GeometryReader { geometry in
        ZStack(alignment: .top) {
          ResizableSplitView(
            top: {
              ZStack {
                // Backdrop background color to cover the top handle area
                Color(UIColor.systemBackground)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Time-passing water backdrop (hide when bottom view is visible or disabled in settings)
                if userPreferences.enableTimeBackdrop {
                  PassingTimeBackdropView(isVisible: !isBottomViewVisible)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .padding(.top, headerHeight - 20)
                }

                // Full-screen scrollable year grid with time-passing backdrop
                ScrollViewReader { scrollProxy in
                  ScrollView(showsIndicators: false) {
                    // Add spacer at top to account for header overlay
                    Spacer()
                      .frame(height: headerHeight)
                      .id("topSpacer")

                    // Use shared JoodleGridInteractionView with optimized hit testing
                    JoodleGridInteractionView(
                      dataProvider: dataProvider,
                      additionalEntries: entries,
                      geometry: geometry,
                      isScrubbing: $isScrubbing,
                      highlightedId: highlightedId,
                      callbacks: createGridCallbacks(geometry: geometry, scrollProxy: scrollProxy),
                      minimumPressDuration: 0.1,
                      allowsHitTesting: true,
                      overlayContent: nil,
                      customHitTestFunction: { location in
                        getItemId(at: location, for: geometry)
                      }
                    )
                    .simultaneousGesture(
                      MagnificationGesture()
                        .onChanged { handlePinchChanged(value: $0) }
                        .onEnded { handlePinchEnded(value: $0) }
                    )
                  }
                  // When view mode changes, rebuild hit testing grid
                  .onChange(of: dataProvider.viewMode) {
                    hitTestingGrid = []  // Clear grid to trigger rebuild
                    gridMetrics = nil

                    if let selectedDateItem = dataProvider.selectedDateItem {
                      // Delay scroll to allow grid animation to complete
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        scrollToRelevantDate(
                          itemId: selectedDateItem.id, scrollProxy: scrollProxy, anchor: .center)
                      }
                    } else {
                      // Delay scroll to allow grid animation to complete
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        scrollToTodayOrTop(scrollProxy: scrollProxy)
                      }
                    }
                  }
                  // When year changes, scroll to relevant date and rebuild hit testing grid
                  .onChange(of: dataProvider.selectedYear) {
                    hitTestingGrid = []  // Clear grid to trigger rebuild
                    gridMetrics = nil
                    // Deselect any selected date item
                    dataProvider.clearSelection()

                    DispatchQueue.main.async {
                      scrollToTodayOrTop(scrollProxy: scrollProxy)
                    }
                  }
                  // Initial scroll to today's dot for both modes
                  .onAppear {
                    yearGridViewSize = geometry.size
                    self.scrollProxy = scrollProxy

                    DispatchQueue.main.async {
                      scrollToTodayOrTop(scrollProxy: scrollProxy)

                      // Auto-select today on launch
                      let currentYear = Calendar.current.component(.year, from: Date())
                      if dataProvider.selectedYear == currentYear {
                        let targetId = dataProvider.getRelevantDateId(for: Date())
                        if let item = dataProvider.getItem(from: targetId) {
                          selectDateItem(item: item, scrollProxy: scrollProxy)
                        }
                      }
                    }
                  }
                  .onDisappear {
                    self.scrollProxy = nil
                  }
                  .scrollDisabled(isScrubbing || isPinching)
                }
              }
            },
            bottom: {
              EntryEditingView(
                date: dataProvider.selectedDateItem?.date,
                entry: selectedEntry,
                onOpenDrawingCanvas: {
                  Haptic.play()
                  // Track if entry already has doodle before opening canvas
                  entryHadDoodleOnCanvasOpen = selectedEntry?.drawingData != nil
                  showDrawingCanvas = true
                },
                onFocusChange: { isFocused in
                  guard isFocused, let selectedDateItem = dataProvider.selectedDateItem, let scrollProxy else { return }

                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    scrollToRelevantDate(
                      itemId: selectedDateItem.id, scrollProxy: scrollProxy, anchor: .center)
                  }
                }
              )
            }, hasBottomView: dataProvider.selectedDateItem != nil,
            onBottomDismissed: {
              dataProvider.clearSelection()
            },
            onTopViewHeightChange: { newHeight in
              yearGridViewSize.height = newHeight
              // Scroll after height change is complete, only do so if there is item selected.
              guard let selectedDateItem = dataProvider.selectedDateItem, let scrollProxy else { return }
              DispatchQueue.main.async {
                scrollToRelevantDate(
                  itemId: selectedDateItem.id, scrollProxy: scrollProxy, anchor: .center)
              }
            }
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .ignoresSafeArea(.container, edges: .bottom)

          // Floating header with blur backdrop
          HeaderView(
            highlightedEntry: currentHighlightedEntry,
            geometry: geometry,
            highlightedItem: currentHighlightedItem,
            selectedYear: Binding(
              get: { dataProvider.selectedYear },
              set: { dataProvider.selectedYear = $0 }
            ),
            viewMode: dataProvider.viewMode,
            onToggleViewMode: { toggleViewMode(to: dataProvider.viewMode == .now ? .year : .now) },
            onSettingsAction: {
              UIApplication.shared.hideKeyboard()
              navigateToSettings = true
            }
          )
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
          date: dataProvider.selectedDateItem!.date,
          entry: selectedEntry,
          onDismiss: {
            handleDrawingCanvasDismiss()
          },
          isShowing: showDrawingCanvas && !UIDevice.hasDynamicIsland
        )
        .padding(.top, 32)
        .disabled(dataProvider.selectedDateItem == nil)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(UIDevice.screenCornerRadius)
        .disableLiquidGlass()
      }
      // Navigate to setting view
      .navigationDestination(isPresented: $navigateToSettings) {
        SettingsView(navigateToNotePromptSetting: $navigateToNotePromptSetting)
      }
      .navigationTitle("Home")
      .toolbar(.hidden, for: .navigationBar)
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
      if UIDevice.hasDynamicIsland && dataProvider.selectedDateItem != nil {
        DynamicIslandExpandedView(
          isExpanded: $showDrawingCanvas,
          content: {
            DrawingCanvasView(
              date: dataProvider.selectedDateItem!.date,
              entry: selectedEntry,
              onDismiss: {
                handleDrawingCanvasDismiss()
              },
              isShowing: showDrawingCanvas
            )
          },
          // Hide dynamic island view when navigate to setting
          hidden: hideDynamicIslandView,
          onDismiss: {
            handleDrawingCanvasDismiss()
          }
        )
        .id("DynamicIslandExpandedView-\(dataProvider.selectedDateItem?.id ?? "none")")
      }

      // Note prompt popup - shown after first doodle
      if showNotePromptPopup {
        NotePromptPopupView(
          isPresented: $showNotePromptPopup,
          onSave: { note in
            saveNoteForEntry(note: note)
          },
          onNavigateToSettings: {
            // Navigate to Customization settings and scroll to note prompt setting
            navigateToNotePromptSetting = true
            navigateToSettings = true
          }
        )
        .zIndex(100)
      }
    }
    .alert("Subscription Ended", isPresented: $subscriptionManager.subscriptionJustExpired) {
      Button("OK") {
        subscriptionManager.acknowledgeExpiry()
      }
    } message: {
      Text("Your Joodle Pro subscription has ended. Some features are now limited.")
    }
    .sheet(isPresented: $showGraceExpiredPaywall) {
      StandalonePaywallView()
    }
    .onAppear {
      // Sync widget data when app launches
      WidgetHelper.shared.updateWidgetData(in: modelContext)

      // Refresh subscription status
      Task {
        await subscriptionManager.updateSubscriptionStatus()
      }

      // Show one-time paywall after grace period expires
      if gracePeriodManager.shouldShowGraceExpiredPaywall && !subscriptionManager.hasPremiumAccess {
        showGraceExpiredPaywall = true
        gracePeriodManager.markGraceExpiredPaywallShown()
        AnalyticsManager.shared.trackGraceExpiredPaywallShown()
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      // Only sync widget data when app goes to background to ensure data is saved
      switch newPhase {
      case .background:
        // App went to background - sync data one final time
        WidgetHelper.shared.updateWidgetData(in: modelContext)
      default:
        break
      }
    }
    .onChange(of: entries.count) { _, newCount in
      // Check if we should prompt for App Store review after reaching 10 entries
      let meaningfulCount = entries.filter { entry in
        let hasDrawing = entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? true)
        let hasText = !entry.body.isEmpty
        return hasDrawing || hasText
      }.count
      ReviewRequestManager.shared.checkAndRequestReviewIfNeeded(entryCount: meaningfulCount)
    }
    .onChange(of: selectedDateFromWidget) { _, newDate in
      // Handle deep link from widget
      guard let date = newDate, let scrollProxy = scrollProxy else { return }

      // Clear the binding after handling
      DispatchQueue.main.async {
        selectedDateFromWidget = nil
      }

      // Update selected year if needed
      let calendar = Calendar.current
      let year = calendar.component(.year, from: date)
      let yearChanged = year != dataProvider.selectedYear
      if yearChanged {
        dataProvider.selectedYear = year
      }

      // Calculate item ID directly from date (ID = timestamp of start of day)
      // This avoids dependency on itemsInYear which may not be updated yet after year change
      let startOfDay = calendar.startOfDay(for: date)
      let itemId = "\(Int(startOfDay.timeIntervalSince1970))"
      let dateItem = DateItem(id: itemId, date: startOfDay)

      // Use longer delay if year changed to allow view to re-render with new items
      let delay = yearChanged ? 0.3 : 0.1
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        dataProvider.selectDateItem(dateItem)
        scrollToRelevantDate(itemId: dateItem.id, scrollProxy: scrollProxy, anchor: .center)
      }
    }
  }

  // MARK: - Grid Interaction Callbacks

  /// Create callbacks for JoodleGridInteractionView
  private func createGridCallbacks(geometry: GeometryProxy, scrollProxy: ScrollViewProxy) -> GridInteractionCallbacks {
    GridInteractionCallbacks(
      onScrubbingBegan: { location in
        highlightedId = nil
        isScrubbing = true
        dataProvider.clearSelection()

        let newId = getItemId(at: location, for: geometry)
        if highlightedId == nil { Haptic.play(with: .medium) }
        highlightedId = newId
      },
      onScrubbingChanged: { location in
        let newId = getItemId(at: location, for: geometry)
        if newId != highlightedId { Haptic.play() }
        highlightedId = newId
      },
      onScrubbingEnded: { _ in
        // Track scrubbing gesture used
        AnalyticsManager.shared.trackScrubbingUsed()

        if let highlightedId, let item = dataProvider.getItem(from: highlightedId) {
          selectDateItem(item: item, scrollProxy: scrollProxy)
        }
        highlightedId = nil
        isScrubbing = false
      },
      onTap: { location in
        if isScrubbing { return }
        guard let itemId = getItemId(at: location, for: geometry),
              let item = dataProvider.getItem(from: itemId)
        else { return }
        selectDateItem(item: item, scrollProxy: scrollProxy)
        Haptic.play()
      }
    )
  }

  /// Calculate spacing between dots based on view mode
  private func calculateSpacing(containerWidth: CGFloat, viewMode: ViewMode) -> CGFloat {
    CalendarGridHelper.calculateSpacing(containerWidth: containerWidth, viewMode: viewMode)
  }

  // MARK: User interactions
  private func handlePinchChanged(value: MagnificationGesture.Value) {
    if isPinching { return }

    isPinching = true

    // Clean up any ongoing drag gesture state when pinch begins
    highlightedId = nil
  }

  private func handlePinchEnded(value: MagnificationGesture.Value) {
    isPinching = false
    highlightedId = nil

    // Pinch in: switch from "now" to "year" mode
    if value < scaleThreshold && dataProvider.viewMode == .now {
      AnalyticsManager.shared.trackPinchGestureUsed(resultingMode: "year")
      toggleViewMode(to: .year)
    }
    // Pinch out: switch from "year" to "now" mode
    else if value > expandThreshold && dataProvider.viewMode == .year {
      AnalyticsManager.shared.trackPinchGestureUsed(resultingMode: "now")
      toggleViewMode(to: .now)
    }
  }

  // MARK: - Hit Testing (O(1) Optimized)

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
    let spacing = calculateSpacing(containerWidth: yearGridViewSize.width, viewMode: dataProvider.viewMode)
    let centeredY = adjustedY + (spacing / 2) + (dataProvider.viewMode.dotSize / 2)
    let row = max(0, Int(floor(centeredY / metrics.rowHeight)))
    let col = max(0, Int(floor(adjustedX / metrics.colWidth)))

    guard row < hitTestingGrid.count,
          col < hitTestingGrid[row].count
    else { return nil }

    return hitTestingGrid[row][col]
  }

  /// Build hit testing grid for fast lookups
  private func buildHitTestingGrid(for geometry: GeometryProxy) {
    let spacing = calculateSpacing(containerWidth: geometry.size.width, viewMode: dataProvider.viewMode)
    let containerWidth = geometry.size.width - (2 * GRID_HORIZONTAL_PADDING)
    let totalSpacingWidth = CGFloat(dataProvider.viewMode.dotsPerRow - 1) * spacing
    let totalDotWidth = containerWidth - totalSpacingWidth
    let itemSpacing = totalDotWidth / CGFloat(dataProvider.viewMode.dotsPerRow)

    let rowHeight = dataProvider.viewMode.dotSize + spacing
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

    // Build 2D grid accounting for leading empty slots
    let numberOfRows = CalendarGridHelper.totalRows(
      forItemCount: dataProvider.itemsInYear.count,
      viewMode: dataProvider.viewMode,
      year: dataProvider.selectedYear
    )
    hitTestingGrid = Array(
      repeating: Array(repeating: nil, count: dataProvider.viewMode.dotsPerRow), count: numberOfRows)

    for (index, item) in dataProvider.itemsInYear.enumerated() {
      // Use CalendarGridHelper for grid position (accounts for leading empty slots)
      let (row, col) = CalendarGridHelper.gridPosition(
        forItemIndex: index,
        viewMode: dataProvider.viewMode,
        year: dataProvider.selectedYear
      )
      hitTestingGrid[row][col] = item.id
    }
  }

  /// Legacy hit testing method (fallback)
  private func getItemIdLegacy(at location: CGPoint, for geometry: GeometryProxy) -> String? {
    let adjustedLocation = adjustTouchLocationForGrid(location)

    // Use CalendarGridHelper for hit testing (handles all grid math and calendar alignment)
    return CalendarGridHelper.itemId(
      at: adjustedLocation,
      containerWidth: geometry.size.width,
      viewMode: dataProvider.viewMode,
      year: dataProvider.selectedYear,
      items: dataProvider.itemsInYear,
      horizontalPaddingAdjustment: false  // Already adjusted by adjustTouchLocationForGrid
    )
  }

  private func selectDateItem(item: DateItem, scrollProxy: ScrollViewProxy) {
    // Don't create entry here - only create when user actually saves content
    // This prevents empty entries from being created just by selecting a date
    dataProvider.selectDateItem(item)
    scrollToRelevantDate(itemId: item.id, scrollProxy: scrollProxy)

  }

  /// Toggle the view mode to a specific mode
  private func toggleViewMode(to newViewMode: ViewMode) {
    let previousMode = dataProvider.viewMode.rawValue

    // Use a spring animation for morphing effect
    withAnimation(.springFkingSatifying) {
      dataProvider.toggleViewMode(to: newViewMode)
    }

    // Track view mode change
    AnalyticsManager.shared.trackViewModeChanged(to: newViewMode.rawValue, from: previousMode)
  }

  // MARK: Layout Calculations
  /// Scrolls to center the selected item by its ID
  private func scrollToRelevantDate(
    itemId: String, scrollProxy: ScrollViewProxy, anchor: UnitPoint? = nil
  ) {
    withAnimation(.springFkingSatifying) {
      scrollProxy.scrollTo(itemId, anchor: anchor)
    }
  }

  /// Scrolls to today's date or first day of year
  private func scrollToTodayOrTop(scrollProxy: ScrollViewProxy) {
    let currentYear = Calendar.current.component(.year, from: Date())

    withAnimation(.springFkingSatifying) {
      if dataProvider.selectedYear != currentYear {
        // For non-current years, scroll to the top spacer to show first row properly
        scrollProxy.scrollTo("topSpacer", anchor: .top)
      } else {
        let targetId = dataProvider.getRelevantDateId(for: Date())
        scrollProxy.scrollTo(targetId, anchor: .center)
      }
    }
  }

  private func getFormattedDate(_ date: Date) -> String {
    return date.formatted(date: .abbreviated, time: .omitted)
  }

  /// Handle drawing canvas dismiss - check if we should show note prompt
  private func handleDrawingCanvasDismiss() {
    let selectedDate = dataProvider.selectedDateItem?.date

    // Close the drawing canvas first
    showDrawingCanvas = false

    // Check if we should show note prompt popup
    // Conditions: setting is enabled, entry didn't have doodle when canvas opened, and now has doodle
    guard userPreferences.promptForNotesAfterDoodling,
          !entryHadDoodleOnCanvasOpen,
          let date = selectedDate
    else { return }

    // Get the entry for this date
    let entry = entries.first(where: { $0.matches(date: date) })

    // Check if the entry now has drawing data (user actually saved something new)
    let entryHasDrawingNow = entry?.drawingData != nil

    // Only show prompt if: entry had no doodle before AND has doodle now
    guard entryHasDrawingNow else { return }

    // Don't show prompt if entry already has notes
    let entryHasNotes = !(entry?.body.isEmpty ?? true)
    guard !entryHasNotes else { return }

    // Store the date for saving notes later
    dateForNotePrompt = date

    // Show the note prompt popup after a short delay for smooth transition
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation {
        showNotePromptPopup = true
      }
    }
  }

  /// Save note from the popup to the entry
  private func saveNoteForEntry(note: String) {
    guard let date = dateForNotePrompt else { return }

    // Find or create entry for this date
    let entryToUpdate = DayEntry.findOrCreate(for: date, in: modelContext)
    entryToUpdate.body = note

    try? modelContext.save()

    dateForNotePrompt = nil
  }

  /// Adjusts the touch location from the parent coordinate system to the grid's coordinate system
  private func adjustTouchLocationForGrid(_ location: CGPoint) -> CGPoint {
    // Adjust for the header height and horizontal padding
    return CGPoint(
      x: location.x - GRID_HORIZONTAL_PADDING,
      y: location.y
    )
  }
}

#Preview {
  ContentView(selectedDateFromWidget: .constant(nil))
    .modelContainer(for: DayEntry.self, inMemory: true)
    .environment(\.userPreferences, UserPreferences.shared)
    .preferredColorScheme(.light)
}
