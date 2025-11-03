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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UserPreferences.self) private var userPreferences
    
    @Query private var entries: [DayEntry]
    
    @State private var selectedDateItem: DateItem?
    
    // --- GESTURE STATE ---
    // Tracks what the user is currently doing
    @State private var isScrubbing = false
    @State private var isPinching = false
    @State private var highlightedId: String?
    // --- END GESTURE STATE ---
    
    @State private var isScrollingDisabled = false  // Kept for pinching
    @State private var viewMode: ViewMode = UserPreferences.shared.defaultViewMode
    @State private var yearGridViewSize: CGSize = .zero
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showDrawingCanvas: Bool = false
    
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
    
    // Gesture states
    private let scaleThreshold: CGFloat = 0.9  // Threshold for detecting significant pinch
    private let expandThreshold: CGFloat = 1.2  // Threshold for detecting significant expand
    
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
    
    private var currentHighlightedItem: DateItem? {
        highlightedId.flatMap { getItem(from: $0) }
    }
    
    private var currentHighlightedEntry: DayEntry? {
        if let itemDate = currentHighlightedItem?.date {
            return entries.first(where: { Calendar.current.isDate($0.createdAt, inSameDayAs: itemDate) })
        }
        return nil
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
                                        // Use isScrubbing to show highlight, fallback to old highlightedId
                                        highlightedItemId: isScrubbing ? highlightedId : nil,
                                        selectedItemId: selectedDateItem?.id
                                    )
                                    .overlay(
                                        LongPressScrubRecognizer(
                                            isScrubbing: $isScrubbing,
                                            minimumPressDuration: 0.1,
                                            allowableMovement: 20,
                                            onBegan: { location in
                                                // Called when long press threshold is reached
                                                // convert location to SwiftUI geometry coords if needed
                                                highlightedId = nil
                                                isScrubbing = true  // if you want to keep using GestureState, you may need to change to @State
                                                // Deselect any currently selected item
                                                selectedDateItem = nil
                                                // play haptic and compute the initial highlightedId
                                                let newId = getItemId(at: location, for: geometry)
                                                if highlightedId == nil { Haptic.play(with: .medium) }
                                                highlightedId = newId
                                            },
                                            onChanged: { location in
                                                // Finger moved while long-press is active
                                                let newId = getItemId(at: location, for: geometry)
                                                if newId != highlightedId { Haptic.play() }
                                                highlightedId = newId
                                            },
                                            onEnded: { location in
                                                // Long-press ended -> finalize selection
                                                if let highlightedId, let item = getItem(from: highlightedId) {
                                                    selectDateItem(item: item, scrollProxy: scrollProxy)
                                                }
                                                highlightedId = nil
                                                isScrubbing = false
                                            }
                                        )
                                        .allowsHitTesting(true)
                                    )
                                    .onTapGesture { location in
                                        // If scrubbing was active, ignore this (scrub handles selection on end)
                                        if isScrubbing { return }
                                        guard let itemId = getItemId(at: location, for: geometry),
                                              let item = getItem(from: itemId)
                                        else { return }
                                        selectDateItem(item: item, scrollProxy: scrollProxy)
                                        Haptic.play()
                                    }
                                    .simultaneousGesture(
                                        MagnificationGesture()
                                            .onChanged { handlePinchChanged(value: $0) }
                                            .onEnded { handlePinchEnded(value: $0) }
                                    )
                                }
                                // Scrolling is now disabled if we are *actively* scrubbing OR pinching
                                .background(.backgroundColor)
                                // When view mode change, rebuild hit testing grid
                                .onChange(of: viewMode) {
                                    hitTestingGrid = []  // Clear grid to trigger rebuild
                                    gridMetrics = nil
                                    
                                    if let selectedDateItem {
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
                                .onChange(of: selectedYear) {
                                    hitTestingGrid = []  // Clear grid to trigger rebuild
                                    gridMetrics = nil
                                    // Deselect any selected date item
                                    selectedDateItem = nil
                                    
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
                                    }
                                }
                                .onDisappear {
                                    self.scrollProxy = nil
                                }
                                .scrollDisabled(isScrubbing || isPinching)
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
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        scrollToRelevantDate(
                                            itemId: selectedDateItem.id, scrollProxy: scrollProxy, anchor: .center)
                                    }
                                }
                            )
                        }, hasBottomView: selectedDateItem != nil,
                        onBottomDismissed: {
                            selectedDateItem = nil
                        },
                        onTopViewHeightChange: { newHeight in
                            yearGridViewSize.height = newHeight
                            // Scroll after height change is complete, only do so if there is item selected.
                            guard let selectedDateItem, let scrollProxy else { return }
                            DispatchQueue.main.async {
                                scrollToRelevantDate(
                                    itemId: selectedDateItem.id, scrollProxy: scrollProxy, anchor: .center)
                            }
                        }
                    )
                    .frame(alignment: .top)
                    .ignoresSafeArea(.container, edges: .bottom)
                    
                    // Floating header with blur backdrop
                    HeaderView(
                        highlightedEntry: currentHighlightedEntry,
                        geometry: geometry,
                        highlightedItem: currentHighlightedItem,
                        selectedYear: $selectedYear,
                        viewMode: viewMode,
                        onToggleViewMode: { toggleViewMode(to: viewMode == .now ? .year : .now) },
                        onSettingsAction: {
                            UIApplication.shared.hideKeyboard()
                            navigateToSettings = true
                        }
                    )
                }
                .background(.backgroundColor)
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
        .onAppear {
            // Sync widget data when app launches
            WidgetHelper.shared.updateWidgetData(with: entries)
        }
        .onChange(of: entries.count) { _, _ in
            // Sync widget data when entries are added or removed
            WidgetHelper.shared.updateWidgetData(with: entries)
        }
        .onChange(of: entries) { _, newEntries in
            // Sync widget data when entries are modified
            WidgetHelper.shared.updateWidgetData(with: newEntries)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Reload widget when app goes to background or comes to foreground
            switch newPhase {
            case .active:
                // App became active (foreground)
                WidgetHelper.shared.updateWidgetData(with: entries)
            case .background:
                // App went to background
                WidgetHelper.shared.updateWidgetData(with: entries)
            case .inactive:
                // App is inactive (transitioning)
                break
            @unknown default:
                break
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
        scrollToRelevantDate(itemId: item.id, scrollProxy: scrollProxy)
    }
    
    /// Toggle the view mode to a specific mode
    private func toggleViewMode(to newViewMode: ViewMode) {
        // Use a spring animation for morphing effect
        withAnimation(.springFkingSatifying) {
            viewMode = newViewMode
        }
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
            if selectedYear != currentYear {
                // For non-current years, scroll to the top spacer to show first row properly
                scrollProxy.scrollTo("topSpacer", anchor: .top)
            } else {
                let targetId = getRelevantDateId(date: Date())
                scrollProxy.scrollTo(targetId, anchor: .center)
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
    ContentView()
        .modelContainer(for: DayEntry.self, inMemory: true)
        .environment(UserPreferences.shared)
        .preferredColorScheme(.light)
}
