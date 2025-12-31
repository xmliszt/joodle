//
//  JoodleGridInteractionView.swift
//  Joodle
//
//  Shared grid interaction view that handles scrubbing, tapping, and pinching gestures.
//  Used by both ContentView (real data) and InteractiveTutorialView (mock data).
//

import SwiftUI

// MARK: - Hit Test Function Type

/// Type alias for custom hit test function
/// Takes a location and returns the item ID at that location, or nil if no item
typealias HitTestFunction = (CGPoint) -> String?

// MARK: - Grid Interaction Callbacks

/// Callbacks for grid interaction events
struct GridInteractionCallbacks {
  /// Called when scrubbing starts
  var onScrubbingBegan: ((CGPoint) -> Void)?

  /// Called when scrubbing location changes
  var onScrubbingChanged: ((CGPoint) -> Void)?

  /// Called when scrubbing ends
  var onScrubbingEnded: ((CGPoint) -> Void)?

  /// Called when a tap occurs on the grid
  var onTap: ((CGPoint) -> Void)?

  /// Called when pinch gesture changes
  var onPinchChanged: ((MagnificationGesture.Value) -> Void)?

  /// Called when pinch gesture ends
  var onPinchEnded: ((MagnificationGesture.Value) -> Void)?

  init(
    onScrubbingBegan: ((CGPoint) -> Void)? = nil,
    onScrubbingChanged: ((CGPoint) -> Void)? = nil,
    onScrubbingEnded: ((CGPoint) -> Void)? = nil,
    onTap: ((CGPoint) -> Void)? = nil,
    onPinchChanged: ((MagnificationGesture.Value) -> Void)? = nil,
    onPinchEnded: ((MagnificationGesture.Value) -> Void)? = nil
  ) {
    self.onScrubbingBegan = onScrubbingBegan
    self.onScrubbingChanged = onScrubbingChanged
    self.onScrubbingEnded = onScrubbingEnded
    self.onTap = onTap
    self.onPinchChanged = onPinchChanged
    self.onPinchEnded = onPinchEnded
  }
}

// MARK: - Grid Interaction View

/// A reusable view component that wraps YearGridView with gesture handling.
/// This component handles scrubbing, tapping, and pinching gestures.
struct JoodleGridInteractionView<DataProvider: JoodleDataProvider>: View {
  // MARK: - Properties

  /// The data provider (real or mock)
  @ObservedObject var dataProvider: DataProvider

  /// Additional entries to display (for cases where entries come from elsewhere, like @Query)
  let additionalEntries: [DayEntry]

  /// The geometry proxy for coordinate calculations
  let geometry: GeometryProxy

  /// Binding to scrubbing state
  @Binding var isScrubbing: Bool

  /// The currently highlighted item ID (during scrubbing)
  let highlightedId: String?

  /// Callbacks for gesture events
  let callbacks: GridInteractionCallbacks

  /// Minimum press duration for scrubbing gesture
  let minimumPressDuration: Double

  /// Whether to allow hit testing on the gesture overlay
  let allowsHitTesting: Bool

  /// Optional overlay content (e.g., tutorial highlight anchor)
  let overlayContent: AnyView?

  /// Optional custom hit test function for O(1) lookups (used by ContentView)
  /// If nil, falls back to CalendarGridHelper.itemId()
  let customHitTestFunction: HitTestFunction?

  // MARK: - Initializer

  init(
    dataProvider: DataProvider,
    additionalEntries: [DayEntry] = [],
    geometry: GeometryProxy,
    isScrubbing: Binding<Bool>,
    highlightedId: String?,
    callbacks: GridInteractionCallbacks,
    minimumPressDuration: Double = 0.1,
    allowsHitTesting: Bool = true,
    overlayContent: AnyView? = nil,
    customHitTestFunction: HitTestFunction? = nil
  ) {
    self.dataProvider = dataProvider
    self.additionalEntries = additionalEntries
    self.geometry = geometry
    self._isScrubbing = isScrubbing
    self.highlightedId = highlightedId
    self.callbacks = callbacks
    self.minimumPressDuration = minimumPressDuration
    self.allowsHitTesting = allowsHitTesting
    self.overlayContent = overlayContent
    self.customHitTestFunction = customHitTestFunction
  }

  // MARK: - Computed Properties

  private var itemsSpacing: CGFloat {
    CalendarGridHelper.calculateSpacing(
      containerWidth: geometry.size.width,
      viewMode: dataProvider.viewMode
    )
  }

  /// Combined entries from data provider and additional entries
  private var allEntries: [DayEntry] {
    let providerEntries = dataProvider.entriesAsDayEntries
    if additionalEntries.isEmpty {
      return providerEntries
    }
    // Merge, with additional entries taking precedence
    var merged = providerEntries
    for entry in additionalEntries {
      if !merged.contains(where: { $0.dateString == entry.dateString }) {
        merged.append(entry)
      }
    }
    return merged
  }

  // MARK: - Body

  var body: some View {
    YearGridView(
      year: dataProvider.selectedYear,
      viewMode: dataProvider.viewMode,
      dotsSpacing: itemsSpacing,
      items: dataProvider.itemsInYear,
      entries: allEntries,
      highlightedItemId: isScrubbing ? highlightedId : nil,
      selectedItemId: dataProvider.selectedDateItem?.id
    )
    .overlay(
      LongPressScrubRecognizer(
        isScrubbing: $isScrubbing,
        minimumPressDuration: minimumPressDuration,
        allowableMovement: 20,
        onBegan: { location in
          callbacks.onScrubbingBegan?(location)
        },
        onChanged: { location in
          callbacks.onScrubbingChanged?(location)
        },
        onEnded: { location in
          callbacks.onScrubbingEnded?(location)
        }
      )
      .allowsHitTesting(allowsHitTesting)
    )
    .onTapGesture { location in
      // If scrubbing was active, ignore this (scrub handles selection on end)
      if isScrubbing { return }
      callbacks.onTap?(location)
    }
    .simultaneousGesture(
      MagnificationGesture()
        .onChanged { value in
          callbacks.onPinchChanged?(value)
        }
        .onEnded { value in
          callbacks.onPinchEnded?(value)
        }
    )
    .overlay(
      Group {
        if let overlayContent = overlayContent {
          overlayContent
        }
      }
    )
  }

  // MARK: - Helper Methods

  /// Get item ID at a location in the grid
  /// Uses custom hit test function if provided (O(1)), otherwise falls back to CalendarGridHelper
  func getItemId(at location: CGPoint) -> String? {
    if let customHitTest = customHitTestFunction {
      return customHitTest(location)
    }
    return CalendarGridHelper.itemId(
      at: location,
      containerWidth: geometry.size.width,
      viewMode: dataProvider.viewMode,
      year: dataProvider.selectedYear,
      items: dataProvider.itemsInYear,
      horizontalPaddingAdjustment: true
    )
  }

  /// Get item from item ID
  func getItem(from itemId: String) -> DateItem? {
    dataProvider.getItem(from: itemId)
  }
}

// MARK: - Standard Gesture Handlers

/// Standard gesture handling that can be used by both ContentView and InteractiveTutorialView
@MainActor
enum JoodleGestureHandlers {

  /// Create standard scrubbing callbacks
  /// - Parameters:
  ///   - dataProvider: The data provider
  ///   - geometry: GeometryProxy for hit testing calculations
  ///   - highlightedId: Binding to the currently highlighted item ID
  ///   - isScrubbing: Binding to the scrubbing state
  ///   - customHitTestFunction: Optional O(1) hit test function (for ContentView)
  ///   - onSelectionComplete: Called when selection is finalized
  ///   - additionalOnBegan: Additional callback when scrubbing begins
  ///   - additionalOnEnded: Additional callback when scrubbing ends
  static func createScrubbingCallbacks<DataProvider: JoodleDataProvider>(
    dataProvider: DataProvider,
    geometry: GeometryProxy,
    highlightedId: Binding<String?>,
    isScrubbing: Binding<Bool>,
    customHitTestFunction: HitTestFunction? = nil,
    onSelectionComplete: ((DateItem) -> Void)? = nil,
    additionalOnBegan: (() -> Void)? = nil,
    additionalOnEnded: (() -> Void)? = nil
  ) -> GridInteractionCallbacks {
    // Helper to get item ID at location
    let getItemId: (CGPoint) -> String? = { location in
      if let customHitTest = customHitTestFunction {
        return customHitTest(location)
      }
      return CalendarGridHelper.itemId(
        at: location,
        containerWidth: geometry.size.width,
        viewMode: dataProvider.viewMode,
        year: dataProvider.selectedYear,
        items: dataProvider.itemsInYear,
        horizontalPaddingAdjustment: true
      )
    }

    return GridInteractionCallbacks(
      onScrubbingBegan: { location in
        highlightedId.wrappedValue = nil
        isScrubbing.wrappedValue = true
        dataProvider.clearSelection()

        let newId = getItemId(location)

        if highlightedId.wrappedValue == nil {
          Haptic.play(with: .medium)
        }
        highlightedId.wrappedValue = newId
        additionalOnBegan?()
      },
      onScrubbingChanged: { location in
        let newId = getItemId(location)

        if newId != highlightedId.wrappedValue {
          Haptic.play()
        }
        highlightedId.wrappedValue = newId
      },
      onScrubbingEnded: { _ in
        if let itemId = highlightedId.wrappedValue,
           let item = dataProvider.getItem(from: itemId) {
          dataProvider.selectDate(item.date)
          onSelectionComplete?(item)
        }
        highlightedId.wrappedValue = nil
        isScrubbing.wrappedValue = false
        additionalOnEnded?()
      }
    )
  }

  /// Create standard tap callback
  /// - Parameters:
  ///   - dataProvider: The data provider
  ///   - geometry: GeometryProxy for hit testing calculations
  ///   - isScrubbing: Current scrubbing state (to ignore taps during scrub)
  ///   - customHitTestFunction: Optional O(1) hit test function (for ContentView)
  ///   - onSelection: Called when an item is selected via tap
  static func createTapCallback<DataProvider: JoodleDataProvider>(
    dataProvider: DataProvider,
    geometry: GeometryProxy,
    isScrubbing: Bool,
    customHitTestFunction: HitTestFunction? = nil,
    onSelection: ((DateItem) -> Void)? = nil
  ) -> (CGPoint) -> Void {
    return { location in
      if isScrubbing { return }

      let itemId: String?
      if let customHitTest = customHitTestFunction {
        itemId = customHitTest(location)
      } else {
        itemId = CalendarGridHelper.itemId(
          at: location,
          containerWidth: geometry.size.width,
          viewMode: dataProvider.viewMode,
          year: dataProvider.selectedYear,
          items: dataProvider.itemsInYear,
          horizontalPaddingAdjustment: true
        )
      }

      guard let itemId,
            let item = dataProvider.getItem(from: itemId)
      else { return }

      dataProvider.selectDate(item.date)
      Haptic.play()
      onSelection?(item)
    }
  }
}
